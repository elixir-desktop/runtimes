defmodule Mix.Tasks.Package.Ios.Nif do
  alias Mix.Tasks.Package.Ios.Runtime
  use Mix.Task
  require EEx

  defdelegate architectures(), to: Runtime
  defdelegate get_arch(arch), to: Runtime
  defdelegate get_nif(nif), to: Runtimes
  defdelegate otp_target(arch), to: Runtime

  def run([nif]) do
    buildall(Map.keys(architectures()), nif)
  end

  def elixir_target() do
    Path.absname("_build/elixir")
  end

  def build(arch, nif) do
    nif = get_nif(nif)
    arch = get_arch(arch)

    # Todo: How to sync cross-compiled erlang version and local erlang version?
    path =
      [
        Path.join(elixir_target(), "bin"),
        # Path.join(otp_target(arch), "bootstrap/bin"),
        System.get_env("PATH")
      ]
      |> Enum.join(":")

    # Getting an Elixir version
    if File.exists?(Path.join(elixir_target(), "bin")) do
      IO.puts("Elixir already exists...")
    else
      Runtimes.run(~w(
        mkdir #{elixir_target()} &&
        cd #{elixir_target()} &&
        wget https://github.com/elixir-lang/elixir/releases/download/v1.11.4/Precompiled.zip &&
        unzip Precompiled.zip
        ))

      Runtimes.run("mix do local.hex --force && mix local.rebar", PATH: path)
    end

    {sdkroot, 0} = System.cmd("xcrun", ["-sdk", arch.sdk, "--show-sdk-path"])

    env = [
      PATH: path,
      ERLANG_PATH: Path.join(otp_target(arch), "release/#{arch.name}/erts-12.0/include"),
      ERTS_INCLUDE_DIR: Path.join(otp_target(arch), "release/#{arch.name}/erts-12.0/include"),
      HOST: arch.name,
      CROSSCOMPILE: "iOS",
      STATIC_ERLANG_NIF: "yes",
      CC: "xcrun -sdk #{arch.sdk} cc -arch #{arch.arch}",
      CFLAGS: arch.cflags,
      CXX: "xcrun -sdk #{arch.sdk} c++ -arch #{arch.arch}",
      CXXFLAGS: arch.cflags,
      LD: "xcrun -sdk #{arch.sdk} ld -arch #{arch.arch}",
      LDFLAGS: "-L#{sdkroot}/usr/lib/ -lc++ -v",
      RANLIB: "xcrun -sdk #{arch.sdk} ranlib",
      AR: "xcrun -sdk #{arch.sdk} ar",
      MIX_ENV: "prod",
      MIX_TARGET: "ios"
    ]

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

    static_lib_path(arch, nif)
  end

  def static_lib_path(arch, nif) do
    nif_dir = "_build/#{arch.name}/#{nif.basename}"

    :filelib.fold_files(
      String.to_charlist(nif_dir),
      '.+\\.a$',
      true,
      fn name, acc -> [List.to_string(name) | acc] end,
      []
    )
    |> List.first()
  end

  defp buildall(targets, nif) do
    for target <- targets do
      build(target, nif)
    end
  end
end
