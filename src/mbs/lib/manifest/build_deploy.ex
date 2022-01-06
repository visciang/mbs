defmodule MBS.Manifest.BuildDeploy do
  @moduledoc false

  alias MBS.{Checksum, Config, Const, Utils}
  alias MBS.Manifest.BuildDeploy.{Component, Toolchain, Type, Validator, Workflow}
  alias MBS.Manifest.{FileDeps, Project}

  @spec find_all(Type.type(), Config.Data.t(), Path.t()) :: [Type.t()]
  def find_all(type, %Config.Data{files_profile: files_profile} = conf, project_dir \\ ".") do
    pre_build_components =
      if type == :deploy do
        find_all(:build, conf, project_dir) |> Map.new(&{&1.id, &1})
      else
        %{}
      end

    project_manifest_path = Path.join(project_dir, Const.manifest_project_filename())
    available_files_profiles = Map.keys(files_profile)

    project_manifest_path
    |> Project.load(type)
    |> Enum.flat_map(fn manifest_path ->
      manifest_path
      |> decode()
      |> Enum.map(&add_defaults(&1, project_dir, manifest_path))
    end)
    |> Validator.validate(type, available_files_profiles)
    |> Workflow.to_type(&to_struct(&1, &2, &3, &4, pre_build_components), type, files_profile)
  end

  @spec component_dependencies_ids(Type.t()) :: [String.t()]
  def component_dependencies_ids(%Toolchain{}), do: []

  def component_dependencies_ids(%Component{toolchain: toolchain, dependencies: dependencies}) do
    [toolchain.id | Enum.map(dependencies, & &1.id)]
  end

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

    manifest_build_filename = Const.manifest_build_filename()
    manifest_deploy_filename = Const.manifest_deploy_filename()
    manifest_toolchain_filename = Const.manifest_toolchain_filename()

    case Path.basename(manifest_path) do
      ^manifest_build_filename -> add_defaults_component(manifest)
      ^manifest_deploy_filename -> add_defaults_component(manifest)
      ^manifest_toolchain_filename -> add_defaults_toolchain(manifest)
    end
  end

  @spec add_defaults_component(map()) :: map()
  defp add_defaults_component(manifest) do
    manifest
    |> Map.put("__schema__", "component")
    |> update_in(["component", "toolchain_opts"], &(&1 || []))
    |> update_in(["component", "dependencies"], &(&1 || []))
    |> update_in(["docker_opts"], &(&1 || %{}))
  end

  @spec add_defaults_toolchain(map()) :: map()
  defp add_defaults_toolchain(manifest) do
    manifest
    |> Map.put("__schema__", "toolchain")
    |> update_in(["toolchain", "files"], &(&1 || []))
    |> update_in(["toolchain", "destroy_steps"], &(&1 || []))
    |> update_in(["docker_build_opts"], &(&1 || []))
  end

  @spec to_struct(Type.type(), map(), %{String.t() => Type.t()}, Config.Data.files_profiles(), %{String.t() => Type.t()}) ::
          Type.t()
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
         upstream_components,
         files_profile,
         pre_build_components
       ) do
    f_prof = Map.get(files_profile, component["files_profile"], [])
    dependencies = Enum.map(component["dependencies"], &Map.fetch!(upstream_components, &1))
    toolchain = Map.fetch!(upstream_components, component["toolchain"])

    {checksum, component_type} =
      case type do
        :build ->
          file_globs =
            Enum.concat([
              [Const.manifest_build_filename()],
              f_prof,
              List.wrap(component["service"]),
              List.wrap(component["files"])
            ])

          files_ = FileDeps.wildcard(dir, file_globs, match_dot: true)
          services = if component["services"] != nil, do: Path.join(dir, component["services"])
          targets = targets(dir, component["targets"])

          checksum = build_checksum_component(dir, files_, toolchain, dependencies)
          component_type = %Component.Build{files: files_, targets: targets, services: services}

          {checksum, component_type}

        :deploy ->
          files_ = FileDeps.wildcard(dir, [Const.manifest_deploy_filename()], match_dot: true)
          build_checksum = Map.fetch!(pre_build_components, id).checksum
          checksum = deploy_checksum_component(dir, files_, toolchain, dependencies, build_checksum)

          build_target_dependencies = targets(dir, component["build_target_dependencies"])

          component_type = %Component.Deploy{build_target_dependencies: build_target_dependencies}

          {checksum, component_type}
      end

    %Component{
      type: component_type,
      id: id,
      dir: dir,
      project_dir: project_dir,
      checksum: checksum,
      toolchain: toolchain,
      toolchain_opts: component["toolchain_opts"],
      timeout: timeout,
      dependencies: dependencies,
      docker_opts: %{
        run: docker_opts["run"] || [],
        shell: docker_opts["shell"] || []
      }
    }
  end

  defp to_struct(
         _type,
         %{
           "__schema__" => "toolchain",
           "id" => id,
           "dir" => dir,
           "project_dir" => project_dir,
           "timeout" => timeout,
           "toolchain" => toolchain,
           "docker_build_opts" => docker_build_opts
         },
         %{},
         files_profile,
         _pre_build_components
       ) do
    f_prof = Map.get(files_profile, toolchain["files_profile"], [])

    file_globs =
      Enum.concat([
        [Const.manifest_toolchain_filename(), toolchain["dockerfile"]],
        f_prof,
        toolchain["files"]
      ])

    files_ = FileDeps.wildcard(dir, file_globs, match_dot: true)

    %Toolchain{
      id: id,
      dir: dir,
      project_dir: project_dir,
      timeout: timeout,
      checksum: checksum_toolchain(dir, files_),
      dockerfile: Path.join(dir, toolchain["dockerfile"]),
      files: files_,
      deps_change_step: toolchain["deps_change_step"],
      steps: toolchain["steps"],
      destroy_steps: toolchain["destroy_steps"],
      docker_build_opts: docker_build_opts
    }
  end

  @spec targets(Path.t(), [String.t()]) :: [Component.Target.t()]
  defp targets(dir, targets) do
    targets
    |> Enum.map(fn
      "docker://" <> target -> %Component.Target{type: :docker, target: target}
      "file://" <> target -> %Component.Target{type: :file, target: Path.join(dir, target)}
      target -> %Component.Target{type: :file, target: Path.join(dir, target)}
    end)
    |> Enum.uniq()
  end

  @spec checksum_toolchain(Path.t(), nonempty_list(Path.t())) :: String.t()
  defp checksum_toolchain(dir, files) do
    Checksum.files_checksum(files, dir)
  end

  @spec build_checksum_component(Path.t(), nonempty_list(Path.t()), Toolchain.t(), [Component.t()]) :: String.t()
  defp build_checksum_component(dir, files, toolchain, dependencies) do
    component_checksum = Checksum.files_checksum(files, dir)

    dependencies_checksums =
      [toolchain | dependencies]
      |> Enum.sort_by(& &1.id)
      |> Enum.map(& &1.checksum)

    [component_checksum | dependencies_checksums]
    |> Enum.join()
    |> Checksum.checksum()
  end

  @spec deploy_checksum_component(Path.t(), nonempty_list(Path.t()), Toolchain.t(), [Component.t()], String.t()) ::
          String.t()
  defp deploy_checksum_component(dir, files, toolchain, dependencies, build_checksum) do
    deploy_partial_checksum = build_checksum_component(dir, files, toolchain, dependencies)

    [build_checksum, deploy_partial_checksum]
    |> Enum.join()
    |> Checksum.checksum()
  end
end
