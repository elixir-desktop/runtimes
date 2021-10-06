defmodule Mix.Tasks.Package.Ios.Runtime do
  @otp_source "https://github.com/diodechain/otp"
  @otp_tag "diode/ios"

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
        cflags: "-mios-version-min=7.0.0 -fno-common -Os -D__IOS__=yes"
      },
      "ios-arm64" => %{
        arch: "arm64",
        id: "ios64",
        sdk: "iphoneos",
        openssl_arch: "ios64-xcrun",
        xcomp: "arm64-ios",
        name: "aarch64-apple-ios",
        cflags: "-mios-version-min=7.0.0 -fno-common -Os -D__IOS__=yes"
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

  def run([]) do
    buildall(Map.keys(architectures()), ["https://github.com/elixir-desktop/exqlite.git"])
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
        if !File.exists?("_build/otp") do
          File.mkdir_p!("_build")

          Runtimes.run(
            "git clone #{@otp_source} _build/otp && cd _build/otp && git checkout #{@otp_tag}"
          )
        end

        Runtimes.run(~w(git clone _build/otp #{otp_target(arch)}))
      end

      env = [
        LIBS: openssl_lib(arch),
        INSTALL_PROGRAM: "/usr/bin/install -c",
        MAKEFLAGS: "-j10 -O",
        RELEASE_LIBBEAM: "yes"
      ]

      nifs = [
        "#{otp_target(arch)}/lib/asn1/priv/lib/#{arch.name}/asn1rt_nif.a",
        "#{otp_target(arch)}/lib/crypto/priv/lib/#{arch.name}/crypto.a"
      ]

      # First round build to generate headers and libs required to build nifs:
      Runtimes.run(
        ~w(
          cd #{otp_target(arch)} && git clean -xdf &&
          ./otp_build autoconf &&
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

      # Second round
      # The extra path can only be generated AFTER the nifs are compiled
      # so this requires two rounds...
      extra_nifs =
        Enum.map(extra_nifs, fn nif ->
          Nif.build(archid, nif)

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

      # [erts_version] = Regex.run(~r/erts-[^ ]+/, File.read!("otp/otp_versions.table"))
      # Locating all built .a files for the target architecture:
      files =
        :filelib.fold_files(
          String.to_charlist(otp_target(arch)),
          '.+\\.a$',
          true,
          fn name, acc -> [List.to_string(name) | acc] end,
          []
        )
        |> Enum.filter(fn name -> String.contains?(name, arch.name) end)

      files = files ++ [openssl_lib(arch) | nifs]

      # Creating a new archive
      repackage_archive(files, runtime_target(arch))
    end
  end

  #  Method takes multiple ".a" archive files and extracts their ".o" contents
  # to then reassemble all of them into a single `target` ".a" archive
  defp repackage_archive(files, target) do
    # Removing relative prefix so changing cwd is safe.
    files = Enum.map(files, fn file -> Path.absname(file) end)

    # Creating a new archive
    cwd = File.cwd!()
    tmp_dir = Path.join(cwd, "_build/tmp")

    if File.exists?(tmp_dir) do
      File.rm_rf!(tmp_dir)
    end

    # Changing cwd to tmp directory
    File.mkdir_p!(tmp_dir)
    :file.set_cwd(String.to_charlist(tmp_dir))

    for file <- files do
      {_, 0} = System.cmd("ar", ["-x", file])
    end

    # Popping back to prev directory and getting object list
    :file.set_cwd(String.to_charlist(cwd))

    objects =
      File.ls!(tmp_dir)
      |> Enum.filter(fn obj -> String.ends_with?(obj, ".o") end)
      |> Enum.map(fn obj -> Path.join(tmp_dir, obj) end)

    {_, 0} = System.cmd("ar", ["-r", target | objects])
  end

  defp buildall(targets, nifs) do
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
