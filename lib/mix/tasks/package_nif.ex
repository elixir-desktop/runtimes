defmodule Mix.Tasks.PackageNif do
  use Mix.Task
  require EEx

  def run(args) do
    {git, tag, tool} =
      case args do
        [] -> raise "Need git url parameter"
        [git] -> {git, nil, :mix}
        ["mix", git] -> {git, nil, :mix}
        ["rebar3", git] -> {git, nil, :rebar3}
        [git, tag] -> {git, tag, :mix}
        ["mix", git, tag] -> {git, tag, :mix}
        ["rebar3", git, tag] -> {git, tag, :rebar3}
      end

    arch = "arm64"
    image_name = "#{Path.basename(git, ".git")}-#{arch}"

    docker_build(image_name, generate_nif_dockerfile(arch, git, tag, tool))
  end

  defp generate_beam_dockerfile(arch) do
    abi =
      case arch do
        "arm" -> 21
        "arm64" -> 23
        "x86_64" -> 23
      end

    cpu =
      case arch do
        "arm64" -> "aarch64"
        other -> other
      end

    args = [arch: arch, cpu: cpu, abi: abi]
    {beam_dockerfile(args), args}
  end

  defp generate_nif_dockerfile(arch, git, tag, tool) do
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

  defp docker_build(image, file) do
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
      {:rebar3, "https://github.com/diodechain/erlang-keccakf1600.git"},
      {:rebar3, "https://github.com/diodechain/libsecp256k1.git"}
    ]
  end
end
