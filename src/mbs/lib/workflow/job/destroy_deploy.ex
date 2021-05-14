defmodule MBS.Workflow.Job.DestroyDeploy do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Toolchain}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t()) :: Job.fun()
  def fun(%Config.Data{} = conf, %BuildDeploy.Toolchain{} = toolchain) do
    Job.RunDeploy.fun(conf, toolchain)
  end

  def fun(
        %Config.Data{},
        %BuildDeploy.Component{dir: component_dir, toolchain: %BuildDeploy.Toolchain{dir: toolchain_dir}} = component
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      report_status =
        with {:ok, build_checksum} <- Job.RunDeploy.build_checksum(component_dir),
             {:ok, toolchain_checksum} <- Job.RunDeploy.build_checksum(toolchain_dir),
             component = put_in(component.toolchain.checksum, toolchain_checksum),
             {:ok, envs} <- Toolchain.RunDeploy.up(component, build_checksum),
             :ok <- Toolchain.RunDeploy.exec_destroy(component, envs) do
          Reporter.Status.ok()
        else
          {:error, reason} ->
            Reporter.Status.error(reason)
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, nil, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{}
    end
  end

  @spec fun_on_exit(Config.Data.t(), BuildDeploy.Type.t()) :: Dask.Job.on_exit()
  def fun_on_exit(config, toolchain) do
    Job.RunDeploy.fun_on_exit(config, toolchain)
  end
end