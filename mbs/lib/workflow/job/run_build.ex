defmodule MBS.Workflow.Job.RunBuild do
  @moduledoc """
  Workflow job logic for "build run" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Docker, Utils}
  alias MBS.Manifest.{BuildDeploy, Dependency}
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t(), boolean()) :: Job.fun()
  def fun(%Config.Data{}, %BuildDeploy.Toolchain{id: id, checksum: checksum} = toolchain, force) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      {cached, report_status, report_desc} =
        with :cache_miss <- cache_get_toolchain(id, checksum, force),
             :ok <- Toolchain.build(toolchain),
             :ok <- Job.Cache.put_toolchain(id, checksum) do
          {false, Reporter.Status.ok(), checksum}
        else
          :cached ->
            {true, Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {false, Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{cached: cached, checksum: checksum, targets: MapSet.new()}
    end
  end

  def fun(%Config.Data{}, %BuildDeploy.Component{id: id, targets: targets} = component, force) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      checksum = Job.Utils.build_checksum(component, upstream_results)

      {cached, report_status, report_desc} =
        with :cache_miss <- cache_get_targets(id, checksum, targets, force),
             changed_deps <- get_changed_dependencies_targets(component, upstream_results, force),
             :ok <- Toolchain.exec_build(component, checksum, upstream_results, changed_deps, job_id),
             :ok <- assert_targets(targets, checksum),
             :ok <- Job.Cache.put_targets(id, checksum, targets) do
          {false, Reporter.Status.ok(), checksum}
        else
          :cached ->
            {true, Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {false, Reporter.Status.error(reason), nil, nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{
        cached: cached,
        checksum: checksum,
        targets: transitive_targets(id, checksum, targets, upstream_results)
      }
    end
  end

  @spec fun_on_exit(Config.Data.t(), BuildDeploy.Type.t()) :: Dask.Job.on_exit()
  def fun_on_exit(%Config.Data{} = config, %BuildDeploy.Toolchain{} = toolchain) do
    Job.OnExit.fun(config, toolchain)
  end

  def fun_on_exit(%Config.Data{} = config, %BuildDeploy.Component{} = component) do
    job_on_exit = Job.OnExit.fun(config, component)

    fn job_id, upstream_results, job_exec_result, elapsed_time_ms ->
      services_up =
        match?({:job_ok, %Job.FunResult{cached: false}}, job_exec_result) or match?(:job_timeout, job_exec_result)

      if services_up do
        Toolchain.exec_services(:down, component, [], job_id)
        job_on_exit.(job_id, upstream_results, job_exec_result, elapsed_time_ms)
      end
    end
  end

  @spec transitive_targets(String.t(), String.t(), [BuildDeploy.Target.t()], Job.upstream_results()) ::
          MapSet.t(BuildDeploy.Target.t())
  defp transitive_targets(id, checksum, targets, upstream_results) do
    expanded_targets = Job.Cache.expand_targets_path(id, checksum, targets)

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

  @spec cache_get_toolchain(String.t(), String.t(), boolean()) :: Job.Cache.cache_result()
  defp cache_get_toolchain(id, checksum, force) do
    if force do
      :cache_miss
    else
      Job.Cache.get_toolchain(id, checksum)
    end
  end

  @spec cache_get_targets(String.t(), String.t(), [BuildDeploy.Target.t()], boolean()) :: Job.Cache.cache_result()
  defp cache_get_targets(id, checksum, targets, force) do
    if force do
      :cache_miss
    else
      Job.Cache.get_targets(id, checksum, targets)
    end
  end

  @spec assert_targets([BuildDeploy.Target.t()], String.t()) :: :ok | {:error, String.t()}
  defp assert_targets([], _checksum), do: :ok

  defp assert_targets(targets, checksum) do
    missing_targets =
      Enum.filter(targets, fn
        %BuildDeploy.Target{type: :file, target: target} ->
          not File.exists?(target)

        %BuildDeploy.Target{type: :docker, target: target} ->
          not Docker.image_exists(target, checksum)
      end)

    if length(missing_targets) != 0 do
      {:error, "Missing targets #{inspect(missing_targets)}"}
    else
      :ok
    end
  end

  @spec get_changed_dependencies_targets(BuildDeploy.Component.t(), Job.upstream_results(), boolean()) ::
          [{Path.t(), Dependency.Type.t()}]
  defp get_changed_dependencies_targets(%BuildDeploy.Component{dir: dir, toolchain: toolchain}, upstream_results, force) do
    local_dependencies_targets_dir = Path.join(dir, Const.local_dependencies_targets_dir())
    File.mkdir_p!(local_dependencies_targets_dir)

    upstream_targets_set =
      upstream_results
      |> Map.values()
      |> Enum.map(& &1.targets)
      |> Utils.union_mapsets()

    res_deps_changed =
      Enum.reduce(upstream_targets_set, [], fn
        {dep_id, %BuildDeploy.Target{type: :file, target: target_cache_path}}, acc ->
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
              %Dependency.Type{id: dep_id, checksum: target_checksum}
            }

            [item | acc]
          else
            acc
          end

        {_dep_id, %BuildDeploy.Target{type: :docker}}, acc ->
          acc
      end)

    toolchain_manifest_path = Path.join(local_dependencies_targets_dir, Const.manifest_dependency_filename())

    res_toolchain_changed =
      if dependency_changed?(toolchain_manifest_path, toolchain.checksum) do
        [
          {
            toolchain_manifest_path,
            %Dependency.Type{id: toolchain.id, checksum: toolchain.checksum}
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
      dependency_manifest = Dependency.load(path)
      dependency_manifest.checksum != checksum
    else
      true
    end
  end
end
