defmodule MBS.Manifest.BuildDeploy do
  @moduledoc false

  alias MBS.{Checksum, Config, Const, Utils}
  alias MBS.Manifest.BuildDeploy.{Component, Target, Toolchain, Type, Validator}
  alias MBS.Manifest.Project

  @spec find_all(Type.type(), Config.Data.t(), Path.t()) :: [Type.t()]
  def find_all(type, %Config.Data{files_profile: files_profile}, project_dir \\ ".") do
    project_manifest_path = Path.join(project_dir, Const.manifest_project_filename())
    available_files_profiles = Map.keys(files_profile)

    project_manifest_path
    |> Project.load(type)
    |> Enum.flat_map(fn manifest_path ->
      manifest_path
      |> decode()
      |> Enum.map(&add_defaults(&1, project_dir, manifest_path))
    end)
    |> Validator.validate(available_files_profiles)
    |> Enum.map(&to_struct(type, &1, files_profile))
    |> add_toolchain_data()
  end

  @spec manifest_name(Type.type()) :: String.t()
  defp manifest_name(:build),
    do: "{#{Const.manifest_toolchain_filename()},#{Const.manifest_build_filename()}}"

  defp manifest_name(:deploy),
    do: "{#{Const.manifest_toolchain_filename()},#{Const.manifest_deploy_filename()}}"

  @spec decode(Path.t()) :: [map()]
  defp decode(manifest_path) do
    manifest_path
    |> File.read!()
    |> Jason.decode()
    |> case do
      {:ok, conf} ->
        List.wrap(conf)

      {:error, reason} ->
        Utils.halt("Error parsing #{manifest_path}\n  #{Jason.DecodeError.message(reason)}")
    end
  end

  @spec add_defaults(map(), Path.t(), Path.t()) :: map()
  defp add_defaults(manifest, project_dir, manifest_path) do
    manifest =
      manifest
      |> put_in(["project_dir"], Path.expand(project_dir))
      |> put_in(["dir"], Path.dirname(Path.expand(manifest_path)))
      |> update_in(["timeout"], &(&1 || :infinity))
      |> update_in(["docker_opts"], &(&1 || []))

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
    manifest
    |> Map.put("__schema__", "component")
    |> update_in(["component", "toolchain_opts"], &(&1 || []))
    |> update_in(["component", "targets"], &(&1 || []))
    |> update_in(["component", "files"], &(&1 || []))
    |> update_in(["component", "dependencies"], &(&1 || []))
  end

  @spec add_defaults_toolchain(map()) :: map()
  defp add_defaults_toolchain(manifest) do
    manifest
    |> Map.put("__schema__", "toolchain")
    |> update_in(["toolchain", "files"], &(&1 || []))
    |> update_in(["toolchain", "destroy_steps"], &(&1 || []))
  end

  @spec to_struct(Type.type(), map(), Config.Data.files_profiles()) :: Type.t()
  defp to_struct(
         type,
         %{
           "__schema__" => "component",
           "id" => id,
           "dir" => dir,
           "project_dir" => project_dir,
           "timeout" => timeout,
           "component" => component,
           "docker_opts" => docker_opts
         },
         files_profile
       ) do
    f_prof = Map.get(files_profile, component["files_profile"], [])
    services_file = if component["services"] != nil, do: [component["services"]], else: []

    %Component{
      type: type,
      id: id,
      dir: dir,
      project_dir: project_dir,
      timeout: timeout,
      toolchain: component["toolchain"],
      toolchain_opts: component["toolchain_opts"],
      files: files(type, dir, f_prof ++ services_file ++ component["files"]),
      targets: targets(dir, component["targets"]),
      dependencies: component["dependencies"],
      services: if(component["services"] != nil, do: Path.join(dir, component["services"])),
      docker_opts: docker_opts
    }
  end

  defp to_struct(
         type,
         %{
           "__schema__" => "toolchain",
           "id" => id,
           "dir" => dir,
           "project_dir" => project_dir,
           "timeout" => timeout,
           "toolchain" => toolchain,
           "docker_opts" => docker_opts
         },
         files_profile
       ) do
    f_prof = Map.get(files_profile, toolchain["files_profile"], [])
    files_ = files(:build, dir, [toolchain["dockerfile"]] ++ f_prof ++ toolchain["files"])

    %Toolchain{
      type: type,
      id: id,
      dir: dir,
      project_dir: project_dir,
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
      "docker://" <> target -> %Target{type: :docker, target: target}
      "file://" <> target -> %Target{type: :file, target: Path.join(dir, target)}
      target -> %Target{type: :file, target: Path.join(dir, target)}
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
      |> Enum.map(&put_in(&1.toolchain, Map.fetch!(get_toolchain, &1.toolchain)))

    toolchains ++ components
  end
end
