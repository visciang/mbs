defmodule Workflow.Exec do
  @moduledoc false

  alias Workflow.Job
  alias Workflow.JobExec
  alias Workflow.Limiter

  @type t :: %__MODULE__{graph: :digraph.graph(), task: Task.t()}
  @enforce_keys [:graph, :task]
  defstruct [:graph, :task]

  @spec exec(:digraph.graph(), Job.t(), Limiter.max_concurrency()) :: :error | :ok
  def exec(graph, %Job{} = workflow_end_job, max_concurrency) do
    {:ok, limiter} = Limiter.start_link(max_concurrency)

    :digraph_utils.topsort(graph)
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn job, job_to_task_map ->
      task = async_workflow_job_task(graph, job, job_to_task_map, limiter)
      Map.put(job_to_task_map, job, task)
    end)
    |> Map.fetch!(workflow_end_job)
    |> Task.await(:infinity)
    |> case do
      {:job_ok, _} -> :ok
      _ -> :error
    end
  end

  defp async_workflow_job_task(graph, %Job{} = job, job_to_task_map, limiter) do
    upstream_job_id_set = :digraph.in_neighbours(graph, job) |> MapSet.new(& &1.id)
    downstream_job_pid_set = :digraph.out_neighbours(graph, job) |> MapSet.new(&job_to_task_map[&1].pid)

    Task.async(fn -> JobExec.exec(job, limiter, upstream_job_id_set, downstream_job_pid_set, %{}) end)
  end
end
