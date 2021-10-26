defmodule Mix.Tasks.Package.Android.Runtime do
  use Mix.Task
  require EEx

  def run(_) do
    buildall(default_archs())
  end

  defp target(arch) do
    "_build/#{arch.android_type}-runtime.zip"
  end

  def build(arch) do
    arch = get_arch(arch)
    file_name = target(arch)

    if File.exists?(file_name) do
      :ok
    else
      Runtimes.ensure_otp()

      {content, _args} = generate_beam_dockerfile(arch.id)
      image_name = "beam-#{arch.id}"
      file = "#{image_name}.dockerfile.tmp"
      File.write!(file, content)
      Runtimes.docker_build(image_name, file)
      File.mkdir_p!("_build/#{arch.id}")

      Runtimes.run(~w(docker run --rm -w
        /work/otp/release/#{arch.pc}-linux-#{arch.android_name}/
        --entrypoint find #{image_name} .
        \\\( -name "*.so" -or -path "*erts-*/bin/*" \\\)
        -exec tar c "{}" + |
        tar x -C _build/#{arch.id}))

      Runtimes.run(
        ~w(find _build/#{arch.id} -name beam.smp -execdir mv beam.smp liberlang.so \\\;)
      )

      Runtimes.run(~w(cd _build/#{arch.id}; zip ../../#{file_name} -r .))
    end
  end

  defp buildall([]) do
    :ok
  end

  defp buildall([head | rest]) do
    build(head)
    buildall(rest)
  end

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
    args = [arch: get_arch(arch), erts_version: Runtimes.erts_version()]
    {beam_dockerfile(args), args}
  end

  def generate_nif_dockerfile(arch, nif) do
    {parent, args} = generate_beam_dockerfile(arch)

    args =
      args ++
        [parent: parent, repo: nif.repo, tag: nif.tag, basename: nif.basename]

    content = nif_dockerfile(args)

    file = "#{nif.basename}-#{arch}.dockerfile.tmp"
    File.write!(file, content)
    file
  end

  EEx.function_from_file(:defp, :nif_dockerfile, "#{__DIR__}/android_nif.dockerfile", [:assigns])

  EEx.function_from_file(:defp, :beam_dockerfile, "#{__DIR__}/android_beam.dockerfile", [:assigns])

  def default_archs() do
    case System.get_env("ARCH", nil) do
      nil -> ["arm", "arm64", "x86_64"]
      arch -> [arch]
    end
  end
end
