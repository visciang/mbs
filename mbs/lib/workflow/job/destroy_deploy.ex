defmodule MBS.Workflow.Job.DestroyDeploy do
  @moduledoc """
  Workflow job logic for "deploy destroy" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Manifest, Toolchain}
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), Manifest.Type.t()) :: Job.fun()
  def fun(%Config.Data{} = conf, %Manifest.Toolchain{} = toolchain) do
    Job.RunDeploy.fun(conf, toolchain, true)
  end

  def fun(
        %Config.Data{},
        %Manifest.Component{dir: component_dir, toolchain: %Manifest.Toolchain{dir: toolchain_dir}} = component
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      report_status =
        with {:ok, build_checksum} <- Job.RunDeploy.build_checksum(component_dir),
             {:ok, toolchain_checksum} <- Job.RunDeploy.build_checksum(toolchain_dir),
             component = put_in(component.toolchain.checksum, toolchain_checksum),
             :ok <- Toolchain.exec_destroy(component, build_checksum, job_id) do
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
end
