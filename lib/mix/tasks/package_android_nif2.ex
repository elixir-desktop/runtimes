defmodule Mix.Tasks.Package.Android.Nif2 do
  import Runtimes.Android
  import Runtimes
  use Mix.Task
  require EEx

  def run([nif]) do
    buildall(Map.keys(architectures()), nif)
  end

  def build(arch, nif) do
    nif = get_nif(nif)
    arch = get_arch(arch)
    env = nif_env(arch)

    # Getting an Elixir version
    if File.exists?(Path.join(elixir_target(arch), "bin")) do
      IO.puts("Elixir already exists...")
    else
      cmd(["scripts/install_elixir.sh", elixir_target(arch)])
      cmd("mix do local.hex --force && mix local.rebar --force", PATH: env[:PATH])
    end

    # Start the builds
    nif_dir = "_build/#{arch.name}/#{nif.basename}"

    if !File.exists?(nif_dir) do
      cmd(~w(git clone #{nif.repo} #{nif_dir}), env)
    end

    if nif.tag do
      cmd(~w(cd #{nif_dir} && git checkout #{nif.tag}), env)
    end

    build_nif = Path.absname("scripts/build_nif.sh")
    cmd(~w(cd #{nif_dir} && #{build_nif}), env)

    case static_lib_path(arch, nif) do
      nil -> raise "NIF build failed. Could not locate static lib"
      lib -> lib
    end
  end

  defp buildall(targets, nif) do
    for target <- targets do
      build(target, nif)
    end
  end
end
