defmodule Mix.Tasks.Package.Nif do
  use Mix.Task
  require EEx

  def run([]) do
    Enum.each(Runtime.default_nifs(), fn nif ->
      {basename, git} =
        case nif do
          git when is_binary(git) -> {basename(git), git}
          {git, basename} -> {basename, git}
        end

      Enum.each(Runtime.default_archs(), fn arch ->
        build(arch, git, basename)
      end)
    end)
  end

  def run(args) do
    {git, tag} =
      case args do
        [] -> raise "Need git url parameter"
        [git] -> {git, nil}
        [git, tag] -> {git, tag}
      end

    build("arm64", git, basename(git), tag)
  end

  defp build(arch, git, basename, tag \\ nil) do
    target = "_build/#{arch}-nif-#{basename}.zip"

    if exists?(target) do
      :ok
    else
      image_name = "#{basename}-#{arch}"

      Runtime.docker_build(
        image_name,
        Runtime.generate_nif_dockerfile(arch, git, tag)
      )

      Runtime.run(~w(docker run --rm
    -w /work/#{basename(git)}/ --entrypoint ./package_nif.sh #{image_name}
    #{basename} > #{target}))
    end
  end

  def exists?(file) do
    case File.stat(file) do
      {:error, _} -> false
      {:ok, %File.Stat{size: 0}} -> false
      _ -> true
    end
  end

  defp basename(git), do: Path.basename(git, ".git")
end
