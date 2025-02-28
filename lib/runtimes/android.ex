defmodule Runtimes.Android do
  require EEx
  import Runtimes

  def architectures() do
    %{
      "arm" => %{
        xcomp: "arm-android",
        openssl_arch: "android-arm",
        id: "arm",
        abi: 34,
        cpu: "arm",
        bin: "armv7a",
        pc: "arm-unknown",
        name: "arm-unknown-linux-androideabi",
        android_name: "androideabi",
        android_type: "armeabi-v7a",
        cflags: "--target=arm-linux-android34 -march=armv7-a -mfpu=neon"
      },
      "arm64" => %{
        xcomp: "arm64-android",
        openssl_arch: "android-arm64",
        id: "arm64",
        abi: 34,
        cpu: "aarch64",
        bin: "aarch64",
        pc: "aarch64-unknown",
        name: "aarch64-unknown-linux-androideabi",
        android_name: "android",
        android_type: "arm64-v8a",
        cflags: "--target=aarch64-linux-android34 -Os"
      },
      "x86_64" => %{
        xcomp: "x86_64-android",
        openssl_arch: "android-x86_64",
        id: "x86_64",
        abi: 34,
        cpu: "x86_64",
        bin: "x86_64",
        pc: "x86_64-pc",
        name: "x86_64-pc-linux-androideabi",
        android_name: "android",
        android_type: "x86_64",
        cflags: "--target=x86_64-linux-android34 -Os"
      }
    }
    |> Map.new()
  end

  def get_arch(arch) do
    Map.fetch!(architectures(), arch)
  end

  # lipo joins different cpu build of the same target together
  def lipo([]), do: []
  def lipo([one]), do: [one]

  def lipo(more) do
    File.mkdir_p!("tmp")
    x = System.unique_integer([:positive])
    tmp = "tmp/#{x}-liberlang.a"
    if File.exists?(tmp), do: File.rm!(tmp)
    cmd("lipo -create #{Enum.join(more, " ")} -output #{tmp}")
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

  def bin_path() do
    Path.join(ndk_home(), "/toolchains/llvm/prebuilt/#{host()}/bin")
  end

  def ensure_ndk_home(env, arch) do
    env = Map.new(env)
    path = env[:PATH] || System.get_env("PATH")
    ndk_abi_plat = "#{arch.android_name}#{arch.abi}"

    Map.merge(
      env,
      %{
        ANDROID_NDK_HOME: ndk_home(),
        PATH: bin_path() <> ":" <> path,
        NDK_ABI_PLAT: ndk_abi_plat,
        CXX: toolpath("clang++", arch),
        CC: toolpath("clang", arch),
        AR: toolpath("ar", arch),
        FC: "",
        CPP: "",
        LD: toolpath("ld", arch),
        LIBTOOL: toolpath("libtool", arch),
        RANLIB: toolpath("ranlib", arch),
        STRIP: toolpath("strip", arch)
      }
    )
    |> Map.to_list()
  end

  def toolpath(tool, arch) do
    stub = Path.absname("./stubs/bin/#{tool}-stub.sh")
    real = real_toolpath(tool, arch)

    if File.exists?(stub) do
      content = File.read!(stub)
      stub = Path.join(stub_target(arch), tool)
      File.mkdir_p!(stub_target(arch))
      File.write!(stub, String.replace(content, "%TOOL%", real || ""))
      File.chmod!(stub, 0o755)
      stub
    else
      real || raise "Tool not found: #{tool} in #{bin_path()}"
    end
  end

  def real_toolpath(tool, arch) do
    [
      tool,
      "llvm-" <> tool,
      "#{arch.cpu}-linux-#{arch.android_name}-#{tool}",
      "#{arch.bin}-linux-#{arch.android_name}-#{tool}"
    ]
    |> Enum.map(fn name -> Path.absname(Path.join(bin_path(), name)) end)
    |> Enum.find(fn name -> File.exists?(name) end)
  end

  def nif_env(arch) do
    path =
      [
        Path.join(elixir_target(arch), "bin"),
        stub_target(arch),
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
