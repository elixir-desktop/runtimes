defmodule Mix.Tasks.Package.Runtime do
  use Mix.Task
  require EEx

  def run(_) do
    buildall(Map.keys(Runtime.architectures()))
  end

  defp target(arch) do
    "_build/#{arch.id}-runtime.zip"
  end

  def build(arch) do
    arch = Runtime.get_arch(arch)
    file_name = target(arch)

    if File.exists?(file_name) do
      :ok
    else
      {content, _args} = Runtime.generate_beam_dockerfile(arch.id)
      image_name = "beam-#{arch.id}"
      file = "#{image_name}.dockerfile.tmp"
      File.write!(file, content)
      Runtime.docker_build(image_name, file)
      File.mkdir_p!("_build/#{arch.id}")

      Runtime.run(~w(docker run --rm -w
        /work/otp/release/#{arch.pc}-linux-#{arch.android_name}/
        --entrypoint find #{image_name} .
        \\\( -name "*.so" -or -path "*erts-*/bin/*" \\\)
        -exec tar c "{}" + |
        tar x -C _build/#{arch.id}))

      Runtime.run(
        ~w(find _build/#{arch.id} -name beam.smp -execdir mv beam.smp liberlang.so \\\;)
      )

      Runtime.run(~w(cd _build/#{arch.id}; zip ../../#{file_name} -r .))
    end
  end

  defp buildall([]) do
    :ok
  end

  defp buildall([head | rest]) do
    build(head)
    buildall(rest)
  end
end
