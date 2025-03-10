defmodule Mix.Tasks.Package.Ios.Nif do
  import Runtimes.Ios
  import Runtimes
  use Mix.Task
  require EEx

  def run([nif]) do
    buildall(Map.keys(architectures()), nif)
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
      cmd(["scripts/install_elixir.sh", elixir_target(arch)])
      cmd("mix do local.hex --force && mix local.rebar --force", PATH: path)
    end

    {sdkroot, 0} = System.cmd("xcrun", ["-sdk", arch.sdk, "--show-sdk-path"])
    sdkroot = String.trim(sdkroot)
    cflags = arch.cflags <> " -isysroot #{sdkroot} -I#{Path.absname("stubs")}"
    # got: ld: only one -syslibroot is accepted for bitcode bundle for architecture armv7
    # lflags = "-Wl,-syslibroot,#{sdkroot} -lc++"
    lflags = "-lc++"
    erts_version = Runtimes.erts_version()

    env = [
      PATH: path,
      ERLANG_PATH:
        Path.join(otp_target(arch), "release/#{arch.name}/erts-#{erts_version}/include"),
      ERTS_INCLUDE_DIR:
        Path.join(otp_target(arch), "release/#{arch.name}/erts-#{erts_version}/include"),
      HOST: arch.name,
      CROSSCOMPILE: "iOS",
      STATIC_ERLANG_NIF: "yes",
      CC: "xcrun -sdk #{arch.sdk} cc -arch #{arch.arch}",
      CFLAGS: cflags,
      CXX: "xcrun -sdk #{arch.sdk} c++ -arch #{arch.arch}",
      CXXFLAGS: cflags,
      LD: "xcrun -sdk #{arch.sdk} ld -arch #{arch.arch}",
      LDFLAGS: lflags,
      RANLIB: "xcrun -sdk #{arch.sdk} ranlib",
      LIBTOOL: "xcrun -sdk #{arch.sdk} libtool",
      AR: "xcrun -sdk #{arch.sdk} ar",
      MIX_ENV: "prod",
      MIX_TARGET: "ios"
    ]

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
