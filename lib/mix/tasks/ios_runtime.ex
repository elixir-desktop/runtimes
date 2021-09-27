defmodule Mix.Tasks.Package.Runtime.Ios do
  use Mix.Task
  require EEx

  def architectures() do
    arch =
      case System.cmd("arch", []) do
        {"arm64", 0} -> "aarch64"
        {"x86_64", 0} -> "x86_64"
        _other -> raise "Can only build ios runtimes on a mac"
      end

    # when build 32-bit arm for iOS then I'm getting this when trying to create
    # a fat binary out of the resulting libbeam.a:
    # Both 'ios-armv7' and 'ios-arm64' represent two equivalent library definitions.
    # so for now it's disabled.
    # Not sure if we still need arm-32 https://blakespot.com/ios_device_specifications_grid.html

    %{
      # "ios" => %{
      #   id: "ios",
      #   sdk: "iphoneos",
      #   openssl_arch: "ios-xcrun",
      #   name: "arm-apple-ios"
      # },
      "ios64" => %{
        id: "ios64",
        sdk: "iphoneos",
        openssl_arch: "ios64-xcrun",
        name: "aarch64-apple-ios"
      },
      "iossimulator" => %{
        id: "iossimulator",
        sdk: "iphoneossimulator",
        openssl_arch: "iossimulator-xcrun",
        name: "#{arch}-apple-iossimulator"
      }
    }
  end

  def get_arch(arch) do
    Map.fetch!(architectures(), arch)
  end

  def run(_) do
    buildall(Map.keys(architectures()))
  end

  def openssl_target(arch) do
    Path.join(System.get_env("HOME"), "projects/#{arch}-openssl")
  end

  def openssl_lib(arch) do
    Path.join(openssl_target(arch), "lib/libcrypto.a")
  end

  def build(arch) do
    arch = get_arch(arch)

    # Building OpenSSL
    if File.exists?(openssl_lib(arch.id)) do
      IO.puts("OpenSSL (#{arch.id}) already exists...")
    else
      Runtimes.run("scripts/install_openssl.sh",
        ARCH: arch.openssl_arch,
        OPENSSL_PREFIX: openssl_target(arch.id)
      )
    end

    # Building OTP
    # Runtimes.run(~w(git clone ../otp))

    target = "_build/#{arch.name}/libbeam.a"

    if File.exists?(target) do
      IO.puts("libbeam.a (#{arch.id}) already exists...")
    else
      env = [
        LIBS: openssl_lib(arch.id),
        INSTALL_PROGRAM: "/usr/bin/install -c",
        MAKEFLAGS: "-j10 -O"
      ]

      config =
        "--with-ssl=#{openssl_target(arch.id)} --disable-dynamic-ssl-lib --xcomp-conf=xcomp/erl-xcomp-#{
          arch.openssl_arch
        }.conf"

      Runtimes.run(
        ~w(cd otp && git clean -xdf &&
      ./otp_build autoconf &&
      ./otp_build configure #{config}
      ),
        env
      )

      Runtimes.run(~w(cd otp && ./otp_build boot -a), env)
      Runtimes.run(~w(cd otp && ./otp_build release -a), env)

      # [erts_version] = Regex.run(~r/erts-[^ ]+/, File.read!("otp/otp_versions.table"))
      File.mkdir_p!("_build/#{arch.name}")

      # Locating all build .a files for the target architecture:
      files =
        :filelib.fold_files(
          '.',
          '.+\\.a$',
          true,
          fn name, acc -> [List.to_string(name) | acc] end,
          []
        )
        |> Enum.filter(fn name -> String.contains?(name, arch.name) end)

      # Creating a new archive
      if File.exists?("tmp") do
        File.rm_rf!("tmp")
      end

      File.mkdir!("tmp")
      :file.set_cwd('tmp')

      for file <- files do
        {_, 0} = System.cmd("ar", ["-x", ".#{file}"])
      end

      objects = File.ls!() |> Enum.filter(fn obj -> String.ends_with?(obj, ".o") end)

      {_, 0} = System.cmd("ar", ["-r", "../#{target}" | objects])
    end
  end

  defp buildall(targets) do
    for target <- targets do
      build(target)
    end

    libs =
      Enum.map(targets, fn target ->
        arch = get_arch(target)
        "-library _build/#{arch.name}/libbeam.a -headers include/ "
      end)

    Runtimes.run(
      "xcodebuild -create-xcframework -output ./libbeam.xcframework " <> Enum.join(libs)
    )
  end
end
