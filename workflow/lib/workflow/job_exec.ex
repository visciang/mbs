defmodule Workflow.JobExec do
  @moduledoc false

  require Logger
  alias Workflow.Job
  alias Workflow.Limiter
  alias Workflow.Utils

  @type exec_result :: {:job_ok, Job.result()} | {:job_error, Job.result()} | :job_skipped | :job_timeout

  @spec exec(Job.t(), pid(), MapSet.t(Job.id()), MapSet.t(pid()), Job.upstream_results()) :: exec_result()
  def exec(%Job{} = job, limiter, upstream_job_id_set, downstream_job_pid_set, upstream_jobs_status) do
    if MapSet.size(upstream_job_id_set) == 0 do
      Logger.debug("START #{inspect(job.id)}  upstream_jobs_status: #{inspect(upstream_jobs_status)}")

      {job_status, elapsed_time} = timed(fn -> exec_job_fun(job, limiter, upstream_jobs_status) end, job.timeout)

      Enum.each(downstream_job_pid_set, &send(&1, {job.id, job_status}))

      Logger.debug(
        "END #{inspect(job.id)}  job_status: #{inspect(job_status)}  -  job_elapsed_time: #{
          Utils.seconds_to_compound_duration(elapsed_time)
        }"
      )

      job_status
    else
      wait_upstream_job_task(job, limiter, upstream_job_id_set, downstream_job_pid_set, upstream_jobs_status)
    end
  end

  defp exec_job_fun(%Job{} = job, limiter, upstream_jobs_status) do
    if Enum.all?(Map.values(upstream_jobs_status), &match?({:job_ok, _}, &1)) do
      try do
        upstream_jobs_result =
          upstream_jobs_status
          |> Map.new(fn {job_id, {_, job_result}} -> {job_id, job_result} end)

        Limiter.wait_my_turn(limiter)

        job.fun.(job.id, upstream_jobs_result)
      rescue
        job_error -> {:job_error, job_error}
      else
        job_result -> {:job_ok, job_result}
      end
    else
      :job_skipped
    end
  end

  defp wait_upstream_job_task(
         job,
         limiter,
         upstream_job_id_set,
         downstream_job_pid_set,
         upstream_jobs_status
       ) do
    receive do
      {upstream_job_id, upstream_job_status} ->
        upstream_job_id_set = MapSet.delete(upstream_job_id_set, upstream_job_id)
        upstream_jobs_status = Map.put(upstream_jobs_status, upstream_job_id, upstream_job_status)
        exec(job, limiter, upstream_job_id_set, downstream_job_pid_set, upstream_jobs_status)
    end
  end

  defp timed(fun, timeout) do
    start_time = System.monotonic_time(:microsecond)

    task = Task.async(fun)

    res =
      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        _ -> :job_timeout
      end

    end_time = System.monotonic_time(:microsecond)

    {res, (end_time - start_time) * :math.pow(10, -6)}
  end
end
