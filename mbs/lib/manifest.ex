defmodule MBS.Manifest.Component do
  @moduledoc false

  defstruct [:id, :dir, :timeout, :toolchain, :toolchain_opts, :files, :targets, :dependencies]
end

defmodule MBS.Manifest.Toolchain do
  @moduledoc false

  defstruct [:id, :dir, :timeout, :checksum, :dockerfile, :files, :steps]
end

defmodule MBS.Manifest.Target do
  @moduledoc false

  defstruct [:type, :target]
end

defmodule MBS.Manifest do
  @moduledoc """
  .mbs.json manifest
  """

  alias MBS.{Checksum, Utils}
  alias MBS.Manifest.{Component, Target, Toolchain, Validator}

  @manifest_filename ".mbs.json"

  def find_all do
    "**/#{@manifest_filename}"
    |> Path.wildcard(match_dot: true)
    |> Enum.map(fn manifest_path ->
      decode(manifest_path)
      |> add_defaults(manifest_path)
    end)
    |> Validator.validate()
    |> Enum.map(&to_struct(&1))
    |> add_toolchain_data()
  end

  defp decode(manifest_path) do
    manifest_path
    |> File.read!()
    |> Jason.decode()
    |> case do
      {:ok, conf} ->
        conf

      {:error, reason} ->
        Utils.halt("Error parsing #{manifest_path}\n  #{Jason.DecodeError.message(reason)}")
    end
  end

  defp add_defaults(manifest, manifest_path) do
    manifest
    |> Map.put("dir", Path.dirname(Path.expand(manifest_path)))
    |> Map.put_new("timeout", :infinity)
  end

  defp to_struct(%{"id" => id, "dir" => dir, "timeout" => timeout, "component" => component}) do
    %Component{
      id: id,
      dir: dir,
      timeout: timeout,
      toolchain: component["toolchain"],
      toolchain_opts: component["toolchain_opts"] || [],
      files: files(dir, component["files"]),
      targets: targets(dir, component["targets"]),
      dependencies: component["dependencies"] || []
    }
  end

  defp to_struct(%{"id" => id, "dir" => dir, "timeout" => timeout, "toolchain" => toolchain}) do
    files_ = files(dir, [toolchain["dockerfile"] | toolchain["files"]])

    %Toolchain{
      id: id,
      dir: dir,
      timeout: timeout,
      checksum: Checksum.files_checksum(files_, dir),
      dockerfile: Path.join(dir, toolchain["dockerfile"]),
      files: files_,
      steps: toolchain["steps"]
    }
  end

  defp files(dir, file_globs) do
    file_globs = [@manifest_filename | file_globs]
    {file_exclude_glob, file_include_glob} = Enum.split_with(file_globs, &String.starts_with?(&1, "!"))

    files_include_match =
      file_include_glob
      |> Stream.flat_map(&Path.wildcard(Path.join(dir, &1), match_dot: true))
      |> MapSet.new()

    files_exclude_match =
      file_exclude_glob
      |> Stream.map(&String.slice(&1, 1..-1))
      |> Stream.flat_map(&Path.wildcard(Path.join(dir, &1), match_dot: true))
      |> MapSet.new()

    files_match = MapSet.difference(files_include_match, files_exclude_match)

    MapSet.to_list(files_match)
  end

  defp targets(dir, targets) do
    targets
    |> Enum.map(fn
      "docker://" <> target ->
        %Target{type: "docker", target: target}

      "file://" <> target ->
        %Target{type: "file", target: Path.join(dir, target)}

      target ->
        %Target{type: "file", target: Path.join(dir, target)}
    end)
    |> Enum.uniq()
  end

  defp add_toolchain_data(manifests) do
    toolchains = Enum.filter(manifests, &match?(%Toolchain{}, &1))
    get_toolchain = Map.new(toolchains, &{&1.id, &1})

    components =
      manifests
      |> Enum.filter(&match?(%Component{}, &1))
      |> Enum.map(&put_in(&1.toolchain, get_toolchain[&1.toolchain]))

    toolchains ++ components
  end
end
