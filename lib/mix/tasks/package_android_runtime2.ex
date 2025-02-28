defmodule Mix.Tasks.Package.Android.Runtime2 do
  import Runtimes.Android
  import Runtimes
  alias Mix.Tasks.Package.Android.Nif2, as: Nif
  use Mix.Task
  require EEx

  def run(["env" | arch]) do
    archs = Map.keys(architectures())
    arch = List.first(arch)

    if !Enum.member?(archs, arch) do
      raise "Architecture '#{arch}' is invalid. Possible values: #{inspect(archs)}"
    end

    File.write!("nif_env.sh", "#!/bin/bash\n")

    nif_env(architectures()[arch])
    |> Enum.sort()
    |> Enum.each(fn {key, value} ->
      File.write!("nif_env.sh", "export #{key}=\"#{value}\"\n", [:append])
    end)

    Mix.shell().info("Environment has been written to nif_env.sh")
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

  def build(archid, extra_nifs) do
    arch = get_arch(archid)
    File.mkdir_p!("_build/#{arch.name}")

    # Building OpenSSL
    if File.exists?(openssl_lib(arch)) do
      IO.puts("OpenSSL (#{arch.id}) already exists...")
    else
      cmd(
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
        cmd(~w(git clone _build/otp #{otp_target(arch)}))

        if !File.exists?(Path.join(otp_target(arch), "patched")) do
          cmd("cd #{otp_target(arch)} && git apply ../../../patch/otp-space.patch")
          File.write!(Path.join(otp_target(arch), "patched"), "true")
        end
      end

      env =
        [
          LIBS: openssl_lib(arch),
          INSTALL_PROGRAM: install_program(),
          MAKEFLAGS: "-j10 -O",
          RELEASE_LIBBEAM: "yes"
        ]
        |> ensure_ndk_home(arch)

      if System.get_env("SKIP_CLEAN_BUILD") == nil do
        nifs = [
          "#{otp_target(arch)}/lib/asn1/priv/lib/#{arch.name}/asn1rt_nif.a",
          "#{otp_target(arch)}/lib/crypto/priv/lib/#{arch.name}/crypto.a"
        ]

        cmd(
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

        cmd(~w(cd #{otp_target(arch)} && ./otp_build boot -a), env)
        cmd(~w(cd #{otp_target(arch)} && ./otp_build release -a), env)
      end

      # Second round
      # The extra path can only be generated AFTER the nifs are compiled
      # so this requires two rounds...
      extra_nifs =
        Enum.map(extra_nifs, fn nif ->
          if static_lib_path(arch, Runtimes.get_nif(nif)) == nil do
            Nif.build(archid, nif)
          end

          static_lib_path(arch, Runtimes.get_nif(nif))
          |> Path.absname()
        end)

      nifs = [
        "#{otp_target(arch)}/lib/asn1/priv/lib/#{arch.name}/asn1rt_nif.a",
        "#{otp_target(arch)}/lib/crypto/priv/lib/#{arch.name}/crypto.a"
        | extra_nifs
      ]

      cmd(
        ~w(
          cd #{otp_target(arch)} && ./otp_build configure
          --with-ssl=#{openssl_target(arch)}
          --disable-dynamic-ssl-lib
          --without-javac --without-odbc --without-wx --without-debugger --without-observer --without-cdv --without-et
          --xcomp-conf=xcomp/erl-xcomp-#{arch.xcomp}.conf
          --enable-static-nifs=#{Enum.join(nifs, ",")}
        ) ++ ["LDFLAGS=\"-z global\""],
        env
      )

      cmd(~w(cd #{otp_target(arch)} && ./otp_build boot -a), env)
      cmd(~w(cd #{otp_target(arch)} && ./otp_build release -a), env)

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
      repackage_archive(toolpath("libtool", arch), files, runtime_target(arch))
    end
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

    files_for_zip =
      Enum.map(targets, fn target ->
        arch = get_arch(target)
        {arch.android_type, runtime_target(arch)}
      end)
      |> Enum.map(fn {android_type, path} ->
        {~c"lib/#{android_type}/liberlang.a", File.read!(path)}
      end)

    :ok = :zip.create(~c"runtime.zip", files_for_zip)
    Mix.shell().info("Created runtime.zip with libraries for targets: #{inspect(targets)}")
  end
end
