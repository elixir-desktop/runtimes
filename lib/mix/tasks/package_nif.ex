defmodule Mix.Tasks.Package.Nif do
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

    Runtime.docker_build(image_name, Runtime.generate_nif_dockerfile(arch, git, tag, tool))
  end
end
