defmodule Runtimes do
  require EEx

  def run(args, env \\ []) do
    args = if is_list(args), do: Enum.join(args, " "), else: args

    env =
      Enum.map(env, fn {key, value} ->
        case key do
          atom when is_atom(atom) -> {Atom.to_string(atom), value}
          _other -> {key, value}
        end
      end)

    IO.puts("RUN: #{args}")

    {ret, 0} =
      System.cmd("bash", ["-c", args],
        stderr_to_stdout: true,
        into: IO.binstream(:stdio, :line),
        env: env
      )

    ret
  end

  def docker_build(image, file) do
    IO.puts("RUN: docker build -t #{image} -f #{file} .")

    ret =
      System.cmd("docker", ~w(build -t #{image} -f #{file} .),
        stderr_to_stdout: true,
        into: IO.binstream(:stdio, :line)
      )

    File.rm(file)
    {_, 0} = ret
  end

  def default_nifs() do
    [
      "https://github.com/diodechain/esqlite.git",
      {"https://github.com/elixir-sqlite/exqlite", tag: "v0.7.5"},
      {"https://github.com/diodechain/erlang-keccakf1600.git", name: "keccakf1600"},
      "https://github.com/diodechain/libsecp256k1.git"
    ]
  end

  def get_nif(url) when is_binary(url) do
    get_nif({url, []})
  end

  def get_nif({url, opts}) do
    name = Keyword.get(opts, :name, Path.basename(url, ".git"))
    tag = Keyword.get(opts, :tag, nil)

    %{
      tag: tag,
      repo: url,
      name: name,
      basename: Path.basename(url, ".git")
    }
  end

  def otp_source() do
    System.get_env("OTP_SOURCE", "https://github.com/diodechain/otp")
  end

  def otp_tag() do
    System.get_env("OTP_TAG", "diode/ios")
  end

  def ensure_otp() do
    if !File.exists?("_build/otp") do
      File.mkdir_p!("_build")

      Runtimes.run(
        "git clone #{Runtimes.otp_source()} _build/otp && cd _build/otp && git checkout #{
          Runtimes.otp_tag()
        }"
      )
    end
  end

  def erts_version() do
    ensure_otp()
    content = File.read!("_build/otp/erts/vsn.mk")
    [[_, vsn]] = Regex.scan(~r/VSN *= *([0-9\.]+)/, content)
    vsn
  end
end
