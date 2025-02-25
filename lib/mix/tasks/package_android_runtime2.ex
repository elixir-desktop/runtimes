defmodule Mix.Tasks.Package.Android.Runtime2 do
  alias Mix.Tasks.Package.Android.Nif2, as: Nif
  use Mix.Task
  require EEx

  def architectures() do
    %{
      "arm" => %{
        xcomp: "arm-android",
        openssl_arch: "android-arm",
        id: "arm",
        abi: 23,
        cpu: "arm",
        pc: "arm-unknown",
        name: "arm-unknown-linux-androideabi",
        android_name: "androideabi",
        android_type: "armeabi-v7a",
        cflags: ""
      },
      "arm64" => %{
        xcomp: "arm64-android",
        openssl_arch: "android-arm64",
        id: "arm64",
        abi: 23,
        cpu: "aarch64",
        pc: "aarch64-unknown",
        name: "aarch64-unknown-linux-androideabi",
        android_name: "android",
        android_type: "arm64-v8a",
        cflags: ""
      },
      "x86_64" => %{
        xcomp: "x86_64-android",
        openssl_arch: "android-x86_64",
        id: "x86_64",
        abi: 23,
        cpu: "x86_64",
        pc: "x86_64-pc",
        name: "x86_64-pc-linux-androideabi",
        android_name: "android",
        android_type: "x86_64",
        cflags: ""
      }
    }
    |> Map.new()
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
      Runtimes.run(
        "scripts/install_openssl.sh",
        [
          ARCH: arch.openssl_arch,
          OPENSSL_PREFIX: openssl_target(arch),
          MAKEFLAGS: "-j10 -O"
        ]
        |> ensure_ndk_home(arch)
      )
    end

    # Building OTP
    if File.exists?(runtime_target(arch)) do
      IO.puts("liberlang.a (#{arch.id}) already exists...")
    else
      if !File.exists?(otp_target(arch)) do
        Runtimes.ensure_otp()
        Runtimes.run(~w(git clone _build/otp #{otp_target(arch)}))

        if !File.exists?(Path.join(otp_target(arch), "patched")) do
          Runtimes.run("cd #{otp_target(arch)} && git apply ../../../patch/otp-space.patch")
          File.write!(Path.join(otp_target(arch), "patched"), "true")
        end
      end

      env =
        [
          LIBS: openssl_lib(arch),
          INSTALL_PROGRAM: "/usr/bin/install -c -s --strip-program=llvm-strip",
          MAKEFLAGS: "-j10 -O",
          RELEASE_LIBBEAM: "yes"
        ]
        |> ensure_ndk_home(arch)

      if System.get_env("SKIP_CLEAN_BUILD") == nil do
        nifs = [
          "#{otp_target(arch)}/lib/asn1/priv/lib/#{arch.name}/asn1rt_nif.a",
          "#{otp_target(arch)}/lib/crypto/priv/lib/#{arch.name}/crypto.a"
        ]

        Runtimes.run(
          ~w(
          cd #{otp_target(arch)} &&
          git clean -xdf &&
          ./otp_build setup
          --with-ssl=#{openssl_target(arch)}
          --disable-dynamic-ssl-lib
          --without-javac --without-odbc --without-wx --without-debugger --without-observer --without-cdv --without-et
          --xcomp-conf=xcomp/erl-xcomp-#{arch.xcomp}.conf
          --enable-static-nifs=#{Enum.join(nifs, ",")}
        ) ++ ["LDFLAGS=\"-z global\""],
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
        ) ++ ["LDFLAGS=\"-z global\""],
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
          ~c".+\\.a$",
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
    if System.get_env("PARALLEL", "") != "" do
      for target <- targets do
        {spawn_monitor(fn -> build(target, nifs) end), target}
      end
      |> Enum.each(fn {{pid, ref}, target} ->
        receive do
          {:DOWN, ^ref, :process, ^pid, :normal} ->
            :ok

          {:DOWN, ^ref, :process, ^pid, reason} ->
            IO.puts("Build failed for #{target}: #{inspect(reason)}")
            raise reason
        end
      end)
    else
      for target <- targets do
        build(target, nifs)
      end
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

  def ensure_ndk_home(env, arch) do
    env = Map.new(env)
    ndk_home = env[:ANDROID_NDK_HOME] || System.get_env("ANDROID_NDK_HOME")

    if ndk_home == nil do
      raise "ANDROID_NDK_HOME is not set"
    end

    path = env[:PATH] || System.get_env("PATH")
    bin = Path.join(ndk_home, "/toolchains/llvm/prebuilt/linux-x86_64/bin")
    ndk_abi_plat = "#{arch.android_name}#{arch.abi}"

    Map.merge(
      env,
      %{
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

  defp toolpath(_bin, "libtool", _arch) do
    tool = Path.absname("./stubs/bin/libtool-stub.sh")

    if File.exists?(tool) do
      tool
    else
      raise "Tool not found: libtool"
    end
  end

  defp toolpath(bin, tool, arch) do
    abi_name = "#{arch.cpu}-linux-#{arch.android_name}-#{tool}"

    cond do
      File.exists?(Path.join(bin, tool)) -> tool
      File.exists?(Path.join(bin, "llvm-" <> tool)) -> "llvm-" <> tool
      File.exists?(Path.join(bin, abi_name)) -> abi_name
      true -> raise "Tool not found: #{abi_name}"
    end
  end
end
