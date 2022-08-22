defmodule Mix.Tasks.Package.Ios.Runtime do
  alias Mix.Tasks.Package.Ios.Nif
  use Mix.Task
  require EEx

  def architectures() do
    # Not sure if we still need arm-32 at all https://blakespot.com/ios_device_specifications_grid.html
    %{
      "ios" => %{
        arch: "armv7",
        id: "ios",
        sdk: "iphoneos",
        openssl_arch: "ios-xcrun",
        xcomp: "arm-ios",
        name: "arm-apple-ios",
        cflags: "-fembed-bitcode -mios-version-min=7.0.0 -fno-common -Os -D__IOS__=yes"
      },
      "ios-arm64" => %{
        arch: "arm64",
        id: "ios64",
        sdk: "iphoneos",
        openssl_arch: "ios64-xcrun",
        xcomp: "arm64-ios",
        name: "aarch64-apple-ios",
        cflags: "-fembed-bitcode -mios-version-min=7.0.0 -fno-common -Os -D__IOS__=yes"
      },
      "iossimulator-x86_64" => %{
        arch: "x86_64",
        id: "iossimulator",
        sdk: "iphonesimulator",
        openssl_arch: "iossimulator-x86_64-xcrun",
        xcomp: "x86_64-iossimulator",
        name: "x86_64-apple-iossimulator",
        cflags: "-mios-simulator-version-min=7.0.0 -fno-common -Os -D__IOS__=yes"
      },
      "iossimulator-arm64" => %{
        arch: "arm64",
        id: "iossimulator",
        sdk: "iphonesimulator",
        openssl_arch: "iossimulator-arm64-xcrun",
        xcomp: "arm64-iossimulator",
        name: "aarch64-apple-iossimulator",
        cflags: "-mios-simulator-version-min=7.0.0 -fno-common -Os -D__IOS__=yes"
      }
    }
  end

  def get_arch(arch) do
    Map.fetch!(architectures(), arch)
  end

  def run(["with_diode_nifs"]) do
    nifs = [
      "https://github.com/diodechain/esqlite.git",
      "https://github.com/diodechain/libsecp256k1.git"
    ]

    run(nifs)
  end

  def run([]) do
    run(["https://github.com/elixir-desktop/exqlite"])
  end

  def run(nifs) do
    IO.puts("Validating nifs...")
    Enum.each(nifs, fn nif -> Runtimes.get_nif(nif) end)
    buildall(Map.keys(architectures()), nifs)
  end

  def openssl_target(arch) do
    Path.absname("_build/#{arch.name}/openssl")
  end

  def openssl_lib(arch) do
    Path.join(openssl_target(arch), "lib/libcrypto.a")
  end

  def otp_target(arch) do
    Path.absname("_build/#{arch.name}/otp")
  end

  def runtime_target(arch) do
    "_build/#{arch.name}/liberlang.a"
  end

  def build(archid, extra_nifs) do
    arch = get_arch(archid)
    File.mkdir_p!("_build/#{arch.name}")

    # Building OpenSSL
    if File.exists?(openssl_lib(arch)) do
      IO.puts("OpenSSL (#{arch.id}) already exists...")
    else
      Runtimes.run("scripts/install_openssl.sh",
        ARCH: arch.openssl_arch,
        OPENSSL_PREFIX: openssl_target(arch)
      )
    end

    # Building OTP
    if File.exists?(runtime_target(arch)) do
      IO.puts("liberlang.a (#{arch.id}) already exists...")
    else
      if !File.exists?(otp_target(arch)) do
        Runtimes.ensure_otp()
        Runtimes.run(~w(git clone _build/otp #{otp_target(arch)}))
      end

      env = [
        LIBS: openssl_lib(arch),
        INSTALL_PROGRAM: "/usr/bin/install -c",
        MAKEFLAGS: "-j10 -O",
        RELEASE_LIBBEAM: "yes"
      ]

      if System.get_env("SKIP_CLEAN_BUILD") == nil do
        nifs = [
          "#{otp_target(arch)}/lib/asn1/priv/lib/#{arch.name}/asn1rt_nif.a",
          "#{otp_target(arch)}/lib/crypto/priv/lib/#{arch.name}/crypto.a"
        ]

        # First round build to generate headers and libs required to build nifs:
        Runtimes.run(
          ~w(
          cd #{otp_target(arch)} &&
          git clean -xdf &&
          ./otp_build configure
          --with-ssl=#{openssl_target(arch)}
          --disable-dynamic-ssl-lib
          --xcomp-conf=xcomp/erl-xcomp-#{arch.xcomp}.conf
          --enable-static-nifs=#{Enum.join(nifs, ",")}
        ),
          env
        )

        Runtimes.run(~w(cd #{otp_target(arch)} && ./otp_build boot -a), env)
        Runtimes.run(~w(cd #{otp_target(arch)} && ./otp_build release -a), env)
      end

      # Second round
      # The extra path can only be generated AFTER the nifs are compiled
      # so this requires two rounds...
      extra_nifs =
        Enum.map(extra_nifs, fn nif ->
          if Nif.static_lib_path(arch, Runtimes.get_nif(nif)) == nil do
            Nif.build(archid, nif)
          end

          Nif.static_lib_path(arch, Runtimes.get_nif(nif))
          |> Path.absname()
        end)

      nifs = [
        "#{otp_target(arch)}/lib/asn1/priv/lib/#{arch.name}/asn1rt_nif.a",
        "#{otp_target(arch)}/lib/crypto/priv/lib/#{arch.name}/crypto.a"
        | extra_nifs
      ]

      Runtimes.run(
        ~w(
          cd #{otp_target(arch)} && ./otp_build configure
          --with-ssl=#{openssl_target(arch)}
          --disable-dynamic-ssl-lib
          --xcomp-conf=xcomp/erl-xcomp-#{arch.xcomp}.conf
          --enable-static-nifs=#{Enum.join(nifs, ",")}
        ),
        env
      )

      Runtimes.run(~w(cd #{otp_target(arch)} && ./otp_build boot -a), env)
      Runtimes.run(~w(cd #{otp_target(arch)} && ./otp_build release -a), env)

      {build_host, 0} = System.cmd("#{otp_target(arch)}/erts/autoconf/config.guess", [])
      build_host = String.trim(build_host)

      # [erts_version] = Regex.run(~r/erts-[^ ]+/, File.read!("otp/otp_versions.table"))
      # Locating all built .a files for the target architecture:
      files =
        :filelib.fold_files(
          String.to_charlist(otp_target(arch)),
          '.+\\.a$',
          true,
          fn name, acc ->
            name = List.to_string(name)

            if String.contains?(name, arch.name) and
                 not (String.contains?(name, build_host) or
                        String.ends_with?(name, "_st.a") or String.ends_with?(name, "_r.a")) do
              Map.put(acc, Path.basename(name), name)
            else
              acc
            end
          end,
          %{}
        )
        |> Map.values()

      files = files ++ [openssl_lib(arch) | nifs]

      # Creating a new archive
      repackage_archive(files, runtime_target(arch))
    end
  end

  #  Method takes multiple ".a" archive files and extracts their ".o" contents
  # to then reassemble all of them into a single `target` ".a" archive
  defp repackage_archive(files, target) do
    # Removing relative prefix so changing cwd is safe.
    files = Enum.join(files, " ")
    Runtimes.run("libtool -static -o #{target} #{files}")
  end

  defp buildall(targets, nifs) do
    Runtimes.ensure_otp()

    # targets
    # |> Enum.map(fn target -> Task.async(fn -> build(target, nifs) end) end)
    # |> Enum.map(fn task -> Task.await(task, 60_000*60*3) end)
    for target <- targets do
      build(target, nifs)
    end

    {sims, reals} =
      Enum.map(targets, fn target -> runtime_target(get_arch(target)) end)
      |> Enum.split_with(fn lib -> String.contains?(lib, "simulator") end)

    libs =
      (lipo(sims) ++ lipo(reals))
      |> Enum.map(fn lib -> "-library #{lib}" end)

    framework = "./_build/liberlang.xcframework"

    if File.exists?(framework) do
      File.rm_rf!(framework)
    end

    Runtimes.run(
      "xcodebuild -create-xcframework -output #{framework} " <>
        Enum.join(libs, " ")
    )
  end

  # lipo joins different cpu build of the same target together
  defp lipo([]), do: []
  defp lipo([one]), do: [one]

  defp lipo(more) do
    File.mkdir_p!("tmp")
    x = System.unique_integer([:positive])
    tmp = "tmp/#{x}-liberlang.a"
    if File.exists?(tmp), do: File.rm!(tmp)
    Runtimes.run("lipo -create #{Enum.join(more, " ")} -output #{tmp}")
    [tmp]
  end
end
