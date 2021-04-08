defmodule MBS.Workflow.Job.RunBuild do
  @moduledoc """
  Workflow job logic for "build run" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, DependencyManifest, Docker, Manifest, Utils}
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), Manifest.Type.t(), boolean()) :: Job.fun()
  def fun(%Config.Data{}, %Manifest.Toolchain{id: id, checksum: checksum} = toolchain, force) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      {report_status, report_desc} =
        with :cache_miss <- cache_get_toolchain(id, checksum, force),
             :ok <- Toolchain.build(toolchain),
             :ok <- Job.Cache.put_toolchain(id, checksum) do
          {Reporter.Status.ok(), checksum}
        else
          :cached ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: checksum, targets: MapSet.new()}
    end
  end

  def fun(%Config.Data{}, %Manifest.Component{id: id, targets: targets} = component, force) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      checksum = Job.Utils.build_checksum(component, upstream_results)

      {report_status, report_desc} =
        with :cache_miss <- cache_get_targets(id, checksum, targets, force),
             changed_deps <- get_changed_dependencies_targets(component, upstream_results, force),
             :ok <- Toolchain.exec_build(component, checksum, upstream_results, changed_deps, job_id),
             :ok <- assert_targets(targets, checksum),
             :ok <- Job.Cache.put_targets(id, checksum, targets) do
          {Reporter.Status.ok(), checksum}
        else
          :cached ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil, nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{
        checksum: checksum,
        targets: transitive_targets(id, checksum, targets, upstream_results)
      }
    end
  end

  @spec transitive_targets(String.t(), String.t(), [Manifest.Target.t()], Job.upstream_results()) ::
          MapSet.t(Manifest.Target.t())
  defp transitive_targets(id, checksum, targets, upstream_results) do
    {:ok, expanded_targets} = Job.Cache.expand_targets_path(id, checksum, targets)

    expanded_targets_set =
      expanded_targets
      |> Enum.map(&{id, &1})
      |> MapSet.new()

    expanded_upstream_targets_set =
      upstream_results
      |> Map.values()
      |> Enum.map(& &1.targets)
      |> Utils.union_mapsets()

    MapSet.union(expanded_targets_set, expanded_upstream_targets_set)
  end

  @spec cache_get_toolchain(String.t(), String.t(), boolean()) :: :cache_miss | :cached
  defp cache_get_toolchain(id, checksum, force) do
    if force do
      :cache_miss
    else
      Job.Cache.get_toolchain(id, checksum)
    end
  end

  @spec cache_get_targets(String.t(), String.t(), [Manifest.Target.t()], boolean()) :: :cache_miss | :cached
  defp cache_get_targets(id, checksum, targets, force) do
    if force do
      :cache_miss
    else
      Job.Cache.get_targets(id, checksum, targets)
    end
  end

  @spec assert_targets([Manifest.Target.t()], String.t()) :: :ok | {:error, String.t()}
  defp assert_targets([], _checksum), do: :ok

  defp assert_targets(targets, checksum) do
    missing_targets =
      Enum.filter(targets, fn
        %Manifest.Target{type: :file, target: target} ->
          not File.exists?(target)

        %Manifest.Target{type: :docker, target: target} ->
          not Docker.image_exists(target, checksum)
      end)

    if length(missing_targets) != 0 do
      {:error, "Missing targets #{inspect(missing_targets)}"}
    else
      :ok
    end
  end

  @spec get_changed_dependencies_targets(Manifest.Component.t(), Job.upstream_results(), boolean()) ::
          [{Path.t(), DependencyManifest.Type.t()}]
  defp get_changed_dependencies_targets(%Manifest.Component{dir: dir, toolchain: toolchain}, upstream_results, force) do
    local_dependencies_targets_dir = Path.join(dir, Const.local_dependencies_targets_dir())
    File.mkdir_p!(local_dependencies_targets_dir)

    upstream_targets_set =
      upstream_results
      |> Map.values()
      |> Enum.map(& &1.targets)
      |> Utils.union_mapsets()

    res_deps_changed =
      Enum.reduce(upstream_targets_set, [], fn
        {dep_id, %Manifest.Target{type: :file, target: target_cache_path}}, acc ->
          target_checksum = target_cache_path |> Path.dirname() |> Path.basename()
          target_filename = Path.basename(target_cache_path)

          dest_dependency_dir = Path.join(local_dependencies_targets_dir, dep_id)
          dest_dependency_path = Path.join(dest_dependency_dir, target_filename)

          dependency_manifest_path = Path.join(dest_dependency_dir, Const.manifest_dependency_filename())

          if force or dependency_changed?(dependency_manifest_path, target_checksum) do
            File.mkdir_p!(dest_dependency_dir)
            File.cp!(target_cache_path, dest_dependency_path)

            item = {
              dependency_manifest_path,
              %DependencyManifest.Type{id: dep_id, checksum: target_checksum}
            }

            [item | acc]
          else
            acc
          end

        {_dep_id, %Manifest.Target{type: :docker}}, acc ->
          acc
      end)

    toolchain_manifest_path = Path.join(local_dependencies_targets_dir, Const.manifest_dependency_filename())

    res_toolchain_changed =
      if dependency_changed?(toolchain_manifest_path, toolchain.checksum) do
        [
          {
            toolchain_manifest_path,
            %DependencyManifest.Type{id: toolchain.id, checksum: toolchain.checksum}
          }
        ]
      else
        []
      end

    res_toolchain_changed ++ res_deps_changed
  end

  @spec dependency_changed?(Path.t(), String.t()) :: boolean()
  defp dependency_changed?(path, checksum) do
    if File.exists?(path) do
      dependency_manifest = DependencyManifest.load(path)
      dependency_manifest.checksum != checksum
    else
      true
    end
  end
end
