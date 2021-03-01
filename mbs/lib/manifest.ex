defmodule MBS.Manifest.Component do
  @moduledoc false

  defstruct [:id, :dir, :toolchain, :files, :targets, :dependencies]
end

defmodule MBS.Manifest.Toolchain do
  @moduledoc false

  defstruct [:id, :dir, :checksum, :dockerfile, :files, :steps]
end

defmodule MBS.Manifest do
  @moduledoc """
  .mbs.json manifest
  """

  alias MBS.Checksum
  alias MBS.Manifest.{Component, Toolchain, Validator}

  @manifest_filename ".mbs.json"

  def find_all do
    "**/#{@manifest_filename}"
    |> Path.wildcard(match_dot: true)
    |> Enum.map(fn manifest_path ->
      Jason.decode!(File.read!(manifest_path))
      |> Map.put("dir", Path.dirname(Path.expand(manifest_path)))
    end)
    |> Validator.validate()
    |> Enum.map(&to_struct(&1))
    |> add_toolchain_data()
  end

  defp to_struct(%{"id" => id, "dir" => dir, "component" => component}) do
    %Component{
      id: id,
      dir: dir,
      toolchain: component["toolchain"],
      files: files(dir, component["files"]),
      targets: targets(dir, component["targets"]),
      dependencies: component["dependencies"] || []
    }
  end

  defp to_struct(%{"id" => id, "dir" => dir, "toolchain" => toolchain}) do
    files_ = files(dir, [toolchain["dockerfile"], toolchain["files"]])

    %Toolchain{
      id: id,
      dir: dir,
      checksum: Checksum.files_checksum(files_),
      dockerfile: Path.join(dir, toolchain["dockerfile"]),
      files: files_,
      steps: toolchain["steps"]
    }
  end

  defp files(dir, file_globs) do
    [@manifest_filename | file_globs]
    |> Enum.flat_map(&Path.wildcard(Path.join(dir, &1), match_dot: true))
    |> Enum.uniq()
  end

  defp targets(dir, targets) do
    targets
    |> Enum.map(&Path.join(dir, &1))
    |> Enum.uniq()
  end

  defp add_toolchain_data(manifests) do
    toolchains = Enum.filter(manifests, &match?(%Toolchain{}, &1))
    get_toolchain = Map.new(toolchains, &{&1.id, &1})

    components =
      manifests
      |> Stream.filter(&match?(%Component{}, &1))
      |> Enum.map(&put_in(&1.toolchain, get_toolchain[&1.toolchain]))

    toolchains ++ components
  end
end
