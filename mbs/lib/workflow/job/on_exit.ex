defmodule MBS.Workflow.Job.OnExit do
  @moduledoc """
  Workflow job logic - on exit callback function
  """

  alias MBS.CLI.Reporter

  require Reporter.Status

  @spec fun(String.t(), Dask.Job.job_exec_result(), non_neg_integer(), Reporter.t()) :: :ok
  def fun(job_id, job_exec_result, elapsed_time_ms, reporter) do
    case job_exec_result do
      :job_timeout ->
        Reporter.job_report(reporter, job_id, Reporter.Status.timeout(), "", elapsed_time_ms * 1_000)

      _ ->
        :ok
    end
  end
end
