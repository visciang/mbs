defmodule MBS.Workflow.Job.OnExit do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Config
  alias MBS.Manifest.BuildDeploy

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t()) :: Dask.Job.on_exit()
  def fun(_config, _component) do
    fn job_id, _upstream_results, job_exec_result, elapsed_time_ms ->
      elapsed_time_s = elapsed_time_ms * 1_000

      case job_exec_result do
        :job_timeout ->
          Reporter.job_report(job_id, Reporter.Status.timeout(), "", elapsed_time_s)

        {:job_error, reason} ->
          error_message = "Internal mbs error"
          Reporter.job_report(job_id, Reporter.Status.error(reason), error_message, elapsed_time_s)

        _ ->
          :ok
      end
    end
  end
end
