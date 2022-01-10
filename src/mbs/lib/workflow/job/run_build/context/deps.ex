defmodule MBS.Workflow.Job.RunBuild.Context.Deps do
  @moduledoc false

  alias MBS.{Const, Docker}
  alias MBS.Manifest.{BuildDeploy, Dependency}
  alias MBS.Workflow.Job

  @type changed_deps :: [{Path.t(), Dependency.Type.t()}]

  @spec put_upstream(BuildDeploy.Component.t(), boolean(), boolean()) :: {:ok, changed_deps()} | {:error, term()}
  def put_upstream(%BuildDeploy.Component{id: id, dir: dir} = component, force, sandboxed) do
    changed_deps = get_changed_targets(component, force)

    case put_dependencies(id, dir, changed_deps, sandboxed) do
      :ok -> {:ok, changed_deps}
      error -> error
    end
  end

  @spec mark_changed(changed_deps(), boolean()) :: :ok
  def mark_changed(_changed_deps, true = _sandboxed) do
    # in sandbox mode we run in an hermetic context, we don't persist any
    # context file during execution (in this case external downloaded dependencies).
    # So there's no need to mark the dependencies that have been changed to optimize
    # subsequent run, we will just run anyway.

    :ok
  end

  def mark_changed(changed_deps, false = _sandboxed) do
    Enum.each(changed_deps, fn {path, type} ->
      Dependency.write(path, type)
    end)
  end

  @spec get_changed_targets(BuildDeploy.Component.t(), boolean()) :: changed_deps()
  defp get_changed_targets(
         %BuildDeploy.Component{dir: component_dir, toolchain: toolchain, dependencies: dependencies},
         force
       ) do
    local_deps_dir = Path.join(component_dir, Const.local_dependencies_targets_dir())

    res_deps_changed =
      dependencies
      |> Enum.flat_map(fn
        %BuildDeploy.Component{
          id: dep_id,
          checksum: dep_checksum,
          type: %BuildDeploy.Component.Build{targets: targets}
        } ->
          Enum.map(targets, &{dep_id, dep_checksum, &1})
      end)
      |> Enum.filter(&match?({_dep_id, _dep_checksum, %BuildDeploy.Component.Target{type: :file}}, &1))
      |> Enum.reduce([], fn {dep_id, dep_checksum, %BuildDeploy.Component.Target{} = dep_target}, acc ->
        dep_target_cache_path = Job.Cache.target_cache_path(dep_id, dep_checksum, dep_target)
        dependency_manifest_path = Path.join([local_deps_dir, dep_id, Const.manifest_dependency_filename()])

        if force or dependency_changed?(dependency_manifest_path, dep_checksum) do
          dependency = %Dependency.Type{id: dep_id, checksum: dep_checksum, cache_path: dep_target_cache_path}
          [{dependency_manifest_path, dependency} | acc]
        else
          acc
        end
      end)

    toolchain_manifest_path = Path.join(local_deps_dir, Const.manifest_dependency_filename())

    res_toolchain_changed =
      if dependency_changed?(toolchain_manifest_path, toolchain.checksum) do
        [{toolchain_manifest_path, %Dependency.Type{id: toolchain.id, checksum: toolchain.checksum}}]
      else
        []
      end

    res_toolchain_changed ++ res_deps_changed
  end

  @spec put_dependencies(String.t(), Path.t(), changed_deps(), boolean()) :: :ok | {:error, term()}
  defp put_dependencies(id, component_dir, deps, true) do
    temp_component_dir = MBS.Utils.mktemp()

    local_deps_dir = Path.join(temp_component_dir, Const.local_dependencies_targets_dir())
    File.mkdir_p!(local_deps_dir)

    deps
    |> Enum.reject(&match?({_, %Dependency.Type{cache_path: nil}}, &1))
    |> Enum.each(fn {_, %Dependency.Type{id: dep_id, cache_path: target_cache_path}} ->
      dest_dir = Path.join(local_deps_dir, dep_id)
      dest_file = Path.join(dest_dir, Path.basename(target_cache_path))
      File.mkdir_p!(Path.join(local_deps_dir, dep_id))
      File.rm_rf!(dest_file)
      File.ln_s!(target_cache_path, dest_file)
    end)

    Docker.container_dput(id, temp_component_dir, component_dir, id)
  end

  defp put_dependencies(_id, component_dir, deps, false) do
    local_deps_dir = Path.join(component_dir, Const.local_dependencies_targets_dir())
    File.mkdir_p!(local_deps_dir)

    deps
    |> Enum.reject(&match?({_, %Dependency.Type{cache_path: nil}}, &1))
    |> Enum.each(fn {_, %Dependency.Type{id: dep_id, cache_path: target_cache_path}} ->
      dest_dir = Path.join(local_deps_dir, dep_id)
      dest_file = Path.join(dest_dir, Path.basename(target_cache_path))
      File.mkdir_p!(Path.join(local_deps_dir, dep_id))
      File.rm_rf!(dest_file)
      File.cp!(target_cache_path, dest_file)
    end)
  end

  @spec dependency_changed?(Path.t(), String.t()) :: boolean()
  defp dependency_changed?(path, checksum) do
    if File.exists?(path) do
      dependency_manifest = Dependency.load(path)
      dependency_manifest.checksum != checksum
    else
      true
    end
  end
end
