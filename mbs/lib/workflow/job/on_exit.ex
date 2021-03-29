defmodule MBS.Workflow.Job.OnExit do
  @moduledoc """
  Workflow job logic - on exit callback function
  """

  alias MBS.CLI.Reporter

  require Reporter.Status

  @spec fun(String.t(), Dask.Job.job_exec_result(), non_neg_integer()) :: :ok
  def fun(job_id, job_exec_result, elapsed_time_ms) do
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
