defmodule MBS.Workflow.Job.RunBuild do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Config
  alias MBS.Manifest.BuildDeploy
  alias MBS.Toolchain
  alias MBS.Workflow.Job
  alias MBS.Workflow.Job.RunBuild.Context

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t(), boolean(), boolean(), boolean()) :: Job.fun()
  def fun(
        %Config.Data{},
        %BuildDeploy.Toolchain{id: id, checksum: checksum} = toolchain,
        force,
        _get_deps_only,
        _sandboxed
      ) do
    fn _job_id, _upstream_results ->
      start_time = Reporter.time()

      {cached, report_status, report_desc} =
        with :cache_miss <- if(force, do: :cache_miss, else: Job.Cache.get_toolchain(id, checksum)),
             :ok <- Toolchain.Common.build(toolchain, force),
             :ok <- Job.Cache.put_toolchain(id, checksum) do
          {false, Reporter.Status.ok(), checksum}
        else
          :cached ->
            {true, Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {false, Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()
      Reporter.job_report(id, report_status, report_desc, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      %Job.FunResult{
        cached: cached,
        checksum: checksum,
        component: nil,
        upstream_cached_targets: MapSet.new()
      }
    end
  end

  def fun(%Config.Data{}, %BuildDeploy.Component{id: id} = component, force, get_deps_only, sandboxed) do
    fn _job_id, upstream_results ->
      start_time = Reporter.time()

      checksum = Job.Utils.build_checksum(component, upstream_results)

      {cached, report_status, report_desc} =
        if get_deps_only do
          run_get_only_deps(component, upstream_results, sandboxed)

          {true, Reporter.Status.uptodate(), checksum}
        else
          run(component, checksum, upstream_results, sandboxed, force)
        end

      end_time = Reporter.time()
      Reporter.job_report(id, report_status, report_desc, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      %Job.FunResult{
        cached: cached,
        checksum: checksum,
        component: component,
        upstream_cached_targets: transitive_cached_targets(component, checksum, upstream_results)
      }
    end
  end

  @spec fun_on_exit(Config.Data.t(), BuildDeploy.Type.t()) :: Dask.Job.on_exit()
  def fun_on_exit(%Config.Data{} = config, %BuildDeploy.Toolchain{} = toolchain) do
    Job.OnExit.fun(config, toolchain)
  end

  def fun_on_exit(%Config.Data{} = config, %BuildDeploy.Component{id: id} = component) do
    job_on_exit = Job.OnExit.fun(config, component)

    fn _job_id, upstream_results, job_exec_result, elapsed_time_ms ->
      if Job.Common.job_started?(job_exec_result) do
        Toolchain.RunBuild.down(component)
        job_on_exit.(id, upstream_results, job_exec_result, elapsed_time_ms)
      end
    end
  end

  @spec run_get_only_deps(BuildDeploy.Component.t(), Job.upstream_results(), boolean()) :: :ok
  defp run_get_only_deps(%BuildDeploy.Component{} = component, upstream_results, sandboxed) do
    Context.Deps.put_upstream(component, upstream_results, true, sandboxed)
    Context.Files.put(component, upstream_components(upstream_results), sandboxed)
  end

  @spec run(BuildDeploy.Component.t(), String.t(), Job.upstream_results(), boolean(), boolean()) ::
          {false, :ok | {:error, binary}, nil | binary}
  defp run(
         %BuildDeploy.Component{id: id, targets: targets} = component,
         checksum,
         upstream_results,
         sandboxed,
         force
       ) do
    with :cache_miss <- if(force, do: :cache_miss, else: Job.Cache.get_targets(id, checksum, targets)),
         {:ok, envs} <- Toolchain.RunBuild.up(component, checksum, upstream_results, not sandboxed),
         :ok <- Context.Config.put(component, sandboxed),
         {:ok, changed_deps} <- Context.Deps.put_upstream(component, upstream_results, force, sandboxed),
         :ok <- Context.Files.put(component, upstream_components(upstream_results), sandboxed),
         :ok <- Toolchain.RunBuild.exec(component, changed_deps, envs),
         :ok <- Context.Deps.mark_changed(changed_deps, sandboxed),
         {:ok, targets} <- Context.Targets.get(component, checksum, sandboxed),
         :ok <- Job.Cache.put_targets(id, checksum, targets) do
      {false, Reporter.Status.ok(), checksum}
    else
      :cached ->
        {true, Reporter.Status.uptodate(), checksum}

      {:error, reason} ->
        {false, Reporter.Status.error(reason), nil}
    end
  end

  @spec transitive_cached_targets(BuildDeploy.Component.t(), String.t(), Job.upstream_results()) ::
          MapSet.t(Job.FunResult.UpstreamCachedTarget.t())
  defp transitive_cached_targets(%BuildDeploy.Component{id: id, targets: targets}, checksum, upstream_results) do
    expanded_targets_set =
      Job.Cache.expand_targets_path(id, checksum, targets)
      |> Enum.map(&%Job.FunResult.UpstreamCachedTarget{component_id: id, target: &1})
      |> MapSet.new()

    upstream_results
    |> Context.Deps.merge_upstream_cached_targets()
    |> MapSet.union(expanded_targets_set)
  end

  @spec upstream_components(Job.upstream_results()) :: [BuildDeploy.Component.t()]
  defp upstream_components(upstream_results) do
    upstream_results
    |> Map.values()
    |> Enum.reject(&(&1.component == nil))
    |> Enum.map(& &1.component)
  end
end
