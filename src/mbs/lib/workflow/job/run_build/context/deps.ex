defmodule MBS.Workflow.Job.RunBuild.Context.Deps do
  @moduledoc false

  alias MBS.{Const, Docker, Utils}
  alias MBS.Manifest.{BuildDeploy, Dependency}
  alias MBS.Workflow.Job

  @type changed_deps :: [{Path.t(), Dependency.Type.t()}]

  @spec put_upstream(BuildDeploy.Component.t(), Job.upstream_results(), boolean(), boolean()) ::
          {:ok, changed_deps()} | {:error, term()}
  def put_upstream(%BuildDeploy.Component{id: id, dir: dir} = component, upstream_results, force, sandboxed) do
    changed_deps = get_changed_targets(component, upstream_results, force)

    case put_dependencies(id, dir, changed_deps, sandboxed) do
      :ok -> {:ok, changed_deps}
      error -> error
    end
  end

  @spec mark_changed(changed_deps(), boolean()) :: :ok
  def mark_changed(_changed_deps, true) do
    # in sandbox mode we run in an hermetic context, we don't persist any
    # context file during execution (in this case external downloaded dependencies).
    # So there's no need to mark the dependencies that have been changed to optimize
    # subsequent run, we will just run anyway.

    :ok
  end

  def mark_changed(changed_deps, false) do
    Enum.each(changed_deps, fn {path, type} ->
      Dependency.write(path, type)
    end)
  end

  @spec merge_upstream_cached_targets(Job.upstream_results()) :: MapSet.t(Job.FunResult.UpstreamCachedTarget.t())
  def merge_upstream_cached_targets(upstream_results) do
    upstream_results
    |> Map.values()
    |> Enum.map(& &1.upstream_cached_targets)
    |> Utils.union_mapsets()
  end

  @spec get_changed_targets(BuildDeploy.Component.t(), Job.upstream_results(), boolean()) :: changed_deps()
  defp get_changed_targets(
         %BuildDeploy.Component{dir: component_dir, toolchain: toolchain},
         upstream_results,
         force
       ) do
    local_deps_dir = Path.join(component_dir, Const.local_dependencies_targets_dir())

    upstream_targets_set = merge_upstream_cached_targets(upstream_results)

    res_deps_changed =
      Enum.reduce(upstream_targets_set, [], fn
        %Job.FunResult.UpstreamCachedTarget{
          component_id: dep_id,
          target: %BuildDeploy.Component.Target{type: :file, target: target_cache_path}
        },
        acc ->
          target_checksum = target_cache_path |> Path.dirname() |> Path.basename()
          dependency_manifest_path = Path.join([local_deps_dir, dep_id, Const.manifest_dependency_filename()])

          if force or dependency_changed?(dependency_manifest_path, target_checksum) do
            dependency = %Dependency.Type{id: dep_id, checksum: target_checksum, cache_path: target_cache_path}
            [{dependency_manifest_path, dependency} | acc]
          else
            acc
          end

        %Job.FunResult.UpstreamCachedTarget{target: %BuildDeploy.Component.Target{type: :docker}}, acc ->
          acc
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
