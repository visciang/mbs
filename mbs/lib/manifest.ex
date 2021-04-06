defmodule MBS.Manifest do
  @moduledoc """
  MBS manifest functions
  """

  alias MBS.{Checksum, Const, ProjectManifest, Utils}
  alias MBS.Manifest.{Component, Target, Toolchain, Type, Validator}

  @spec find_all(Type.type(), Path.t()) :: [Type.t()]
  def find_all(type, in_dir \\ ".") do
    project_manifest_path = Path.join(in_dir, Const.manifest_project_filename())

    ProjectManifest.load(type, project_manifest_path)
    |> Enum.map(fn manifest_path ->
      manifest_path
      |> decode()
      |> add_defaults(manifest_path)
    end)
    |> Validator.validate()
    |> Enum.map(&to_struct(type, &1))
    |> add_toolchain_data()
  end

  @spec manifest_name(Type.type()) :: String.t()
  defp manifest_name(:build),
    do: "{#{Const.manifest_toolchain_filename()},#{Const.manifest_build_filename()}}"

  defp manifest_name(:deploy),
    do: "{#{Const.manifest_toolchain_filename()},#{Const.manifest_deploy_filename()}}"

  @spec decode(Path.t()) :: map()
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

  @spec add_defaults(map(), Path.t()) :: map()
  defp add_defaults(manifest, manifest_path) do
    manifest = put_in(manifest["dir"], Path.dirname(Path.expand(manifest_path)))
    manifest = Map.put_new(manifest, "timeout", :infinity)

    manifest = put_in(manifest["docker_opts"], manifest["docker_opts"] || [])

    manifest_build_filename = Const.manifest_build_filename()
    manifest_deploy_filename = Const.manifest_deploy_filename()
    manifest_toolchain_filename = Const.manifest_toolchain_filename()

    case Path.basename(manifest_path) do
      ^manifest_build_filename -> add_defaults_build(manifest)
      ^manifest_deploy_filename -> add_defaults_build(manifest)
      ^manifest_toolchain_filename -> add_defaults_toolchain(manifest)
    end
  end

  @spec add_defaults_build(map()) :: map()
  defp add_defaults_build(manifest) do
    manifest = Map.put(manifest, "__schema__", "component")

    if manifest["component"] do
      manifest = put_in(manifest["component"]["toolchain_opts"], manifest["component"]["toolchain_opts"] || [])
      manifest = put_in(manifest["component"]["targets"], manifest["component"]["targets"] || [])
      put_in(manifest["component"]["dependencies"], manifest["component"]["dependencies"] || [])
    else
      manifest
    end
  end

  @spec add_defaults_toolchain(map()) :: map()
  defp add_defaults_toolchain(manifest) do
    manifest = Map.put(manifest, "__schema__", "toolchain")
    put_in(manifest["toolchain"]["destroy_steps"], manifest["toolchain"]["destroy_steps"] || [])
  end

  @spec to_struct(Type.type(), map()) :: Type.t()
  defp to_struct(type, %{
         "__schema__" => "component",
         "id" => id,
         "dir" => dir,
         "timeout" => timeout,
         "component" => component,
         "docker_opts" => docker_opts
       }) do
    %Component{
      type: type,
      id: id,
      dir: dir,
      timeout: timeout,
      toolchain: component["toolchain"],
      toolchain_opts: component["toolchain_opts"],
      files: files(type, dir, component["files"]),
      targets: targets(dir, component["targets"]),
      dependencies: component["dependencies"],
      docker_opts: docker_opts
    }
  end

  defp to_struct(type, %{
         "__schema__" => "toolchain",
         "id" => id,
         "dir" => dir,
         "timeout" => timeout,
         "toolchain" => toolchain,
         "docker_opts" => docker_opts
       }) do
    files_ = files(:build, dir, [toolchain["dockerfile"] | toolchain["files"]])

    %Toolchain{
      type: type,
      id: id,
      dir: dir,
      timeout: timeout,
      checksum: Checksum.files_checksum(files_, dir),
      dockerfile: Path.join(dir, toolchain["dockerfile"]),
      files: files_,
      deps_change_step: toolchain["deps_change_step"],
      steps: toolchain["steps"],
      destroy_steps: toolchain["destroy_steps"],
      docker_opts: docker_opts
    }
  end

  @spec files(Type.type(), Path.t(), [String.t()]) :: [Path.t()]
  defp files(:build, dir, file_globs) do
    file_globs = [manifest_name(:build), manifest_name(:deploy) | file_globs]
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

  defp files(:deploy, dir, files) do
    targets(dir, files)
  end

  @spec targets(Path.t(), [String.t()]) :: [Target.t()]
  defp targets(dir, targets) do
    targets
    |> Enum.map(fn
      "docker://" <> target ->
        %Target{type: :docker, target: target}

      "file://" <> target ->
        %Target{type: :file, target: Path.join(dir, target)}

      target ->
        %Target{type: :file, target: Path.join(dir, target)}
    end)
    |> Enum.uniq()
  end

  @spec add_toolchain_data([Type.t()]) :: [Type.t()]
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
