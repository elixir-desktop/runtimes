defmodule Mix.Tasks.Package.Runtime.Ios do
  use Mix.Task
  require EEx

  def architectures() do
    %{
      "ios" => %{
        id: "ios",
        sdk: "iphoneos",
        openssl_arch: "ios-xcrun"
      },
      "ios64" => %{
        id: "ios64",
        sdk: "iphoneos",
        openssl_arch: "ios64-xcrun"
      },
      "iossimulator" => %{
        id: "iossimulator",
        sdk: "iphoneossimulator",
        openssl_arch: "iossimulator-xcrun"
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

    env = [
      LIBS: openssl_lib(arch.id),
      # ARCH: arch.id,
      INSTALL_PROGRAM: "/usr/bin/install -c",
      MAKEFLAGS: "-j10 -O"
    ]

    config =
      "--with-ssl=#{openssl_target(arch.id)}/ --disable-dynamic-ssl-lib --xcomp-conf=xcomp/erl-xcomp-#{arch.openssl_arch}.conf"


    Runtimes.run(
      ~w(cd otp && git clean -xdf &&
      ./otp_build autoconf &&
      ./otp_build configure #{config}
      ),
      env
    )


    IO.puts("DOING BOOT")
    Runtimes.run(~w(cd otp && ./otp_build boot -a), env)
    IO.puts("DOING LIBBEAM")
    Runtimes.run(~w(cd otp && ./otp_build release -a), env)

    {:ok} = Process.exit(self(), :killed)

  end

  defp buildall([]) do
    :ok
  end

  defp buildall([head | rest]) do
    build(head)
    buildall(rest)
  end
end
