defmodule Mix.Tasks.Package.Android.Nif do
  use Mix.Task
  alias Mix.Tasks.Package.Android.Runtime
  require EEx

  def run([]) do
    for nif <- Runtimes.default_nifs() do
      for arch <- Runtime.default_archs() do
        build(arch, Runtimes.get_nif(nif))
      end
    end
  end

  def run(args) do
    {git, _tag} =
      case args do
        [] -> raise "Need git url parameter"
        [git] -> {git, nil}
        [git, tag] -> {git, tag}
      end

    build("arm64", Runtimes.get_nif(git))
  end

  defp build(arch, nif) do
    type = Runtime.get_arch(arch).android_type
    target = "_build/#{type}-nif-#{nif.name}.zip"

    if exists?(target) do
      :ok
    else
      image_name = "#{nif.name}-#{arch}"

      Runtimes.docker_build(
        image_name,
        Runtime.generate_nif_dockerfile(arch, nif)
      )

      Runtimes.run(~w(docker run --rm
    -w /work/#{nif.basename}/ --entrypoint ./package_nif.sh #{image_name}
    #{nif.name} > #{target}))
    end
  end

  def exists?(file) do
    case File.stat(file) do
      {:error, _} -> false
      {:ok, %File.Stat{size: 0}} -> false
      _ -> true
    end
  end
end
