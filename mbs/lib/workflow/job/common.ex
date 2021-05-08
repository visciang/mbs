defmodule MBS.Workflow.Job.Common do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec job_started?(Dask.Job.job_exec_result()) :: boolean()
  def job_started?(:job_skipped), do: false
  def job_started?({:job_ok, %Job.FunResult{cached: true}}), do: false
  def job_started?(_), do: true

  @spec stop_on_failure(Reporter.Status.t()) :: nil
  def stop_on_failure(Reporter.Status.ok()), do: nil
  def stop_on_failure(Reporter.Status.uptodate()), do: nil
  def stop_on_failure(status), do: raise("Job failed #{inspect(status)}")
end
