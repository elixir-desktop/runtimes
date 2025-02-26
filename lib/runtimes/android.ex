defmodule Runtimes.Android do
  require EEx
  import Runtimes

  def architectures() do
    %{
      "arm" => %{
        xcomp: "arm-android",
        openssl_arch: "android-arm",
        id: "arm",
        abi: 23,
        cpu: "arm",
        bin: "armv7a",
        pc: "arm-unknown",
        name: "arm-unknown-linux-androideabi",
        android_name: "androideabi",
        android_type: "armeabi-v7a",
        cflags: "--target=arm-linux-android23"
      },
      "arm64" => %{
        xcomp: "arm64-android",
        openssl_arch: "android-arm64",
        id: "arm64",
        abi: 23,
        cpu: "aarch64",
        bin: "aarch64",
        pc: "aarch64-unknown",
        name: "aarch64-unknown-linux-androideabi",
        android_name: "android",
        android_type: "arm64-v8a",
        cflags: "--target=aarch64-linux-android23"
      },
      "x86_64" => %{
        xcomp: "x86_64-android",
        openssl_arch: "android-x86_64",
        id: "x86_64",
        abi: 23,
        cpu: "x86_64",
        bin: "x86_64",
        pc: "x86_64-pc",
        name: "x86_64-pc-linux-androideabi",
        android_name: "android",
        android_type: "x86_64",
        cflags: "--target=x86_64-linux-android23"
      }
    }
    |> Map.new()
  end

  def get_arch(arch) do
    Map.fetch!(architectures(), arch)
  end

  #  Method takes multiple ".a" archive files and extracts their ".o" contents
  # to then reassemble all of them into a single `target` ".a" archive
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

  def ndk_home() do
    System.get_env("ANDROID_NDK_HOME") ||
      guess_ndk_home() || raise "ANDROID_NDK_HOME is not set"
  end

  def guess_ndk_home() do
    home = System.get_env("HOME")

    base =
      case :os.type() do
        {:unix, :linux} -> Path.join(home, "Android/Sdk/ndk")
        {:unix, :darwin} -> Path.join(home, "Library/Android/sdk/ndk")
      end

    case File.ls(base) do
      {:ok, versions} -> Path.join(base, List.last(Enum.sort(versions)))
      _ -> raise "No NDK found in #{base}"
    end
  end

  def ensure_ndk_home(env, arch) do
    env = Map.new(env)
    path = env[:PATH] || System.get_env("PATH")
    bin = Path.join(ndk_home(), "/toolchains/llvm/prebuilt/#{host()}/bin")
    ndk_abi_plat = "#{arch.android_name}#{arch.abi}"

    Map.merge(
      env,
      %{
        ANDROID_NDK_HOME: ndk_home(),
        PATH: bin <> ":" <> path,
        NDK_ABI_PLAT: ndk_abi_plat,
        CXX: toolpath(bin, "clang++", arch),
        CC: toolpath(bin, "clang", arch),
        AR: toolpath(bin, "ar", arch),
        FC: "",
        CPP: "",
        LD: toolpath(bin, "ld", arch),
        LIBTOOL: toolpath(bin, "libtool", arch),
        RANLIB: toolpath(bin, "ranlib", arch),
        STRIP: toolpath(bin, "strip", arch)
      }
    )
    |> Map.to_list()
  end

  def toolpath(_bin, "ld", _arch) do
    tool = Path.absname("./stubs/bin/ld-stub.sh")

    if File.exists?(tool) do
      tool
    else
      raise "Tool not found: ld"
    end
  end

  def toolpath(_bin, "libtool", _arch) do
    tool = Path.absname("./stubs/bin/libtool-stub.sh")

    if File.exists?(tool) do
      tool
    else
      raise "Tool not found: libtool"
    end
  end

  def toolpath(bin, tool, arch) do
    [
      tool,
      "llvm-" <> tool,
      "#{arch.cpu}-linux-#{arch.android_name}-#{tool}",
      "#{arch.bin}-linux-#{arch.android_name}-#{tool}"
    ]
    |> Enum.find(fn name -> File.exists?(Path.join(bin, name)) end)
    |> case do
      nil -> raise "Tool not found: #{tool}"
      name -> Path.absname(Path.join(bin, name))
    end
  end

  def nif_env(arch) do
    path =
      [
        Path.join(elixir_target(arch), "bin"),
        Path.join(System.get_env("HOME"), ".mix"),
        # Path.join(otp_target(arch), "bootstrap/bin"),
        System.get_env("PATH")
      ]
      |> Enum.join(":")

    cflags =
      arch.cflags <>
        " -I#{Path.absname("stubs")}"

    lflags =
      "-v -lc++ -L#{Path.join(ndk_home(), "toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/#{arch.cpu}-linux-android/#{arch.abi}")}"

    erts_version = Runtimes.erts_version()

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
  end
end
