defmodule Runtimes.Ios do
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

  #  Method takes multiple ".a" archive files and extracts their ".o" contents
  # to then reassemble all of them into a single `target` ".a" archive
  def repackage_archive(files, target) do
    # Removing relative prefix so changing cwd is safe.
    files = Enum.join(files, " ")
    Runtimes.run("libtool -static -o #{target} #{files}")
  end

  # lipo joins different cpu build of the same target together
  def lipo([]), do: []
  def lipo([one]), do: [one]

  def lipo(more) do
    File.mkdir_p!("tmp")
    x = System.unique_integer([:positive])
    tmp = "tmp/#{x}-liberlang.a"
    if File.exists?(tmp), do: File.rm!(tmp)
    Runtimes.run("lipo -create #{Enum.join(more, " ")} -output #{tmp}")
    [tmp]
  end

  def elixir_target(arch) do
    Path.absname("_build/#{arch.name}/elixir")
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
end
