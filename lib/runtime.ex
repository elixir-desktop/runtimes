defmodule Runtime do
  require EEx

  def architectures() do
    %{
      "arm" => %{
        id: "arm",
        abi: 23,
        cpu: "arm",
        pc: "arm-unknown",
        android_name: "androideabi",
        android_type: "armeabi-v7a"
      },
      "arm64" => %{
        id: "arm64",
        abi: 23,
        cpu: "aarch64",
        pc: "aarch64-unknown",
        android_name: "android",
        android_type: "arm64-v8a"
      },
      "x86_64" => %{
        id: "x86_64",
        abi: 23,
        cpu: "x86_64",
        pc: "x86_64-pc",
        android_name: "android",
        android_type: "x86_64"
      }
    }
  end

  def get_arch(arch) do
    Map.fetch!(architectures(), arch)
  end

  def generate_beam_dockerfile(arch) do
    args = [arch: get_arch(arch)]
    {beam_dockerfile(args), args}
  end

  def generate_nif_dockerfile(arch, git, tag, tool) do
    {parent, args} = generate_beam_dockerfile(arch)

    args =
      args ++
        [parent: parent, repo: git, tag: tag, basename: Path.basename(git, ".git"), tool: tool]

    content = nif_dockerfile(args)

    file = "#{Path.basename(git, ".git")}-#{arch}.dockerfile.tmp"
    File.write!(file, content)
    file
  end

  EEx.function_from_file(:defp, :nif_dockerfile, "#{__DIR__}/nif.dockerfile", [:assigns])
  EEx.function_from_file(:defp, :beam_dockerfile, "#{__DIR__}/beam.dockerfile", [:assigns])

  def run(args) do
    args = if is_list(args), do: Enum.join(args, " "), else: args
    IO.puts("RUN: #{args}")

    {_, 0} =
      System.cmd("bash", ["-c", args],
        stderr_to_stdout: true,
        into: IO.binstream(:stdio, :line)
      )
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

  def default_archs() do
    ["arm", "arm64", "x86_64"]
  end

  def default_nifs() do
    [
      {:rebar3, "https://github.com/mmzeeman/esqlite.git"},
      {:mix, "https://github.com/elixir-sqlite/exqlite.git"},
      {:rebar3, "https://github.com/diodechain/erlang-keccakf1600.git", :keccakf1600},
      {:rebar3, "https://github.com/diodechain/libsecp256k1.git"}
    ]
  end
end
