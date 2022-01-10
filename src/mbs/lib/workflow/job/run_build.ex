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
        %Config.Data{} = config,
        %BuildDeploy.Toolchain{id: id, checksum: checksum} = toolchain,
        force,
        _get_deps_only,
        _sandboxed
      ) do
    fn _job_id, _upstream_results ->
      start_time = Reporter.time()

      {cached, report_status, report_desc} =
        with :cache_miss <- if(force, do: :cache_miss, else: Job.Cache.get_toolchain(config, id, checksum)),
             :ok <- Toolchain.Common.build(config, toolchain, force),
             :ok <- Job.Cache.put_toolchain(config, id, checksum) do
          {false, Reporter.Status.ok(), checksum}
        else
          :cached ->
            {true, Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {false, Reporter.Status.error(reason, nil), nil}
        end

      end_time = Reporter.time()
      Reporter.job_report(id, report_status, report_desc, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      %Job.FunResult{cached: cached}
    end
  end

  def fun(
        %Config.Data{} = config,
        %BuildDeploy.Component{id: id, checksum: checksum} = component,
        force,
        get_deps_only,
        sandboxed
      ) do
    fn _job_id, _upstream_results ->
      start_time = Reporter.time()

      {cached, report_status, report_desc} =
        if get_deps_only do
          run_get_only_deps(component, sandboxed)

          {true, Reporter.Status.uptodate(), checksum}
        else
          run(config, component, sandboxed, force)
        end

      end_time = Reporter.time()
      Reporter.job_report(id, report_status, report_desc, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      %Job.FunResult{cached: cached}
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

  @spec run_get_only_deps(BuildDeploy.Component.t(), boolean()) :: :ok
  defp run_get_only_deps(%BuildDeploy.Component{} = component, sandboxed) do
    Context.Deps.put_upstream(component, true, sandboxed)
    Context.Files.put(component, sandboxed)
  end

  @spec run(Config.Data.t(), BuildDeploy.Component.t(), boolean(), boolean()) ::
          {boolean(), Reporter.Status.t(), nil | String.t()}
  defp run(
         %Config.Data{} = config,
         %BuildDeploy.Component{
           id: id,
           checksum: checksum,
           type: %BuildDeploy.Component.Build{targets: targets}
         } = component,
         sandboxed,
         force
       ) do
    with :cache_miss <- if(force, do: :cache_miss, else: Job.Cache.get_targets(config, id, checksum, targets)),
         {:ok, envs} <- Toolchain.RunBuild.up(config, component, not sandboxed),
         :ok <- Context.Config.put(component, sandboxed),
         {:ok, changed_deps} <- Context.Deps.put_upstream(component, force, sandboxed),
         :ok <- Context.Files.put(component, sandboxed),
         :ok <- Toolchain.RunBuild.exec(component, envs),
         :ok <- Context.Deps.mark_changed(changed_deps, sandboxed),
         {:ok, targets} <- Context.Targets.get(component, checksum, sandboxed),
         :ok <- Job.Cache.put_targets(config, id, checksum, targets) do
      {false, Reporter.Status.ok(), checksum}
    else
      :cached ->
        {true, Reporter.Status.uptodate(), checksum}

      {:error, reason} ->
        {false, Reporter.Status.error(reason, nil), nil}
    end
  end
end
