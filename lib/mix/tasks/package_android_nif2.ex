defmodule Mix.Tasks.Package.Android.Nif2 do
  alias Mix.Tasks.Package.Android.Runtime2, as: Runtime
  use Mix.Task
  require EEx

  defdelegate architectures(), to: Runtime
  defdelegate get_arch(arch), to: Runtime
  defdelegate get_nif(nif), to: Runtimes
  defdelegate otp_target(arch), to: Runtime
  defdelegate ensure_ndk_home(env, arch), to: Runtime

  def run([nif]) do
    buildall(Map.keys(architectures()), nif)
  end

  def elixir_target(arch) do
    Path.absname("_build/#{arch.name}/elixir")
  end

  def build(arch, nif) do
    nif = get_nif(nif)
    arch = get_arch(arch)

    # Todo: How to sync cross-compiled erlang version and local erlang version?
    path =
      [
        Path.join(elixir_target(arch), "bin"),
        Path.join(System.get_env("HOME"), ".mix"),
        # Path.join(otp_target(arch), "bootstrap/bin"),
        System.get_env("PATH")
      ]
      |> Enum.join(":")

    # Getting an Elixir version
    if File.exists?(Path.join(elixir_target(arch), "bin")) do
      IO.puts("Elixir already exists...")
    else
      Runtimes.run(["scripts/install_elixir.sh", elixir_target(arch)])
      Runtimes.run("mix do local.hex --force && mix local.rebar --force", PATH: path)
    end

    cflags =
      arch.cflags <>
        " -I#{Path.absname("stubs")}"

    lflags =
      "-lc++ -L#{Path.join(Runtime.ndk_home(), "toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/#{arch.cpu}-linux-android/#{arch.abi}")}"

    erts_version = Runtimes.erts_version()

    env =
      [
        PATH: path,
        ERLANG_PATH:
          Path.join(otp_target(arch), "release/#{arch.name}/erts-#{erts_version}/include"),
        ERTS_INCLUDE_DIR:
          Path.join(otp_target(arch), "release/#{arch.name}/erts-#{erts_version}/include"),
        HOST: arch.name,
        CROSSCOMPILE: "Android",
        STATIC_ERLANG_NIF: "yes",
        CFLAGS: cflags,
        CXXFLAGS: cflags,
        LDFLAGS: lflags,
        MIX_ENV: "prod",
        MIX_TARGET: "Android"
      ]
      |> ensure_ndk_home(arch)

    # Start the builds
    nif_dir = "_build/#{arch.name}/#{nif.basename}"

    if !File.exists?(nif_dir) do
      Runtimes.run(~w(git clone #{nif.repo} #{nif_dir}), env)
    end

    if nif.tag do
      Runtimes.run(~w(cd #{nif_dir} && git checkout #{nif.tag}), env)
    end

    build_nif = Path.absname("scripts/build_nif.sh")
    Runtimes.run(~w(cd #{nif_dir} && #{build_nif}), env)

    case static_lib_path(arch, nif) do
      nil -> raise "NIF build failed. Could not locate static lib"
      lib -> lib
    end
  end

  def static_lib_path(arch, nif) do
    nif_dir = "_build/#{arch.name}/#{nif.basename}"

    # Finding all .a files
    :filelib.fold_files(
      String.to_charlist(nif_dir),
      ~c".+\\.a$",
      true,
      fn name, acc -> [List.to_string(name) | acc] end,
      []
    )
    |> Enum.filter(fn path -> String.contains?(path, "priv") end)
    |> List.first()
  end

  defp buildall(targets, nif) do
    for target <- targets do
      build(target, nif)
    end
  end
end
