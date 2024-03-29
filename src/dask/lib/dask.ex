defmodule Dask do
  @moduledoc false

  defmodule Error do
    defexception [:message]
  end

  alias Dask.Exec
  alias Dask.Job
  alias Dask.Limiter

  defstruct [:jobs]
  @type t :: %Dask{jobs: %{Job.id() => Job.t()}}

  @type await_result :: {:ok, Job.upstream_results()} | {:error, Job.upstream_results()} | :timeout

  @spec start_job_id :: :__start_job__
  def start_job_id, do: :__start_job__

  @spec end_job_id :: :__end_job__
  def end_job_id, do: :__end_job__

  @spec new :: Dask.t()
  def new do
    %Dask{jobs: %{}}
  end

  @spec job(Dask.t(), Job.id(), Job.fun(), timeout(), Job.on_exit()) :: Dask.t()
  def job(%Dask{} = workflow, job_id, job_fun, job_timeout \\ :infinity, on_exit \\ fn _, _, _, _ -> :ok end) do
    job = %Job{id: job_id, fun: job_fun, timeout: job_timeout, downstream_jobs: MapSet.new(), on_exit: on_exit}
    put_in(workflow.jobs[job_id], job)
  end

  @spec flow(Dask.t(), Job.id(), Job.id()) :: Dask.t()
  @spec flow(Dask.t(), Job.id(), [Job.id()]) :: Dask.t()
  @spec flow(Dask.t(), [Job.id()], Job.id()) :: Dask.t()
  def flow(%Dask{} = workflow, job_up, jobs_down) when is_list(jobs_down) do
    Enum.reduce(jobs_down, workflow, &flow(&2, job_up, &1))
  end

  def flow(%Dask{} = workflow, jobs_up, job_down) when is_list(jobs_up) do
    Enum.reduce(jobs_up, workflow, &flow(&2, &1, job_down))
  end

  def flow(%Dask{} = workflow, job_up, job_down) do
    if not Map.has_key?(workflow.jobs, job_up) do
      raise Error, "Unknown job #{inspect(job_up)}"
    end

    if not Map.has_key?(workflow.jobs, job_down) do
      raise Error, "Unknown job #{inspect(job_down)}"
    end

    downstream_jobs = MapSet.put(workflow.jobs[job_up].downstream_jobs, job_down)
    put_in(workflow.jobs[job_up].downstream_jobs, downstream_jobs)
  end

  @spec depends_on(Dask.t(), Job.id(), [Job.id()]) :: Dask.t()
  @spec depends_on(Dask.t(), [Job.id()], Job.id()) :: Dask.t()
  @spec depends_on(Dask.t(), Job.id(), Job.id()) :: Dask.t()
  def depends_on(%Dask{} = workflow, job, depends_on_job) do
    flow(workflow, depends_on_job, job)
  end

  @spec async(Dask.t(), Limiter.max_concurrency()) :: Exec.t()
  def async(%Dask{} = workflow, max_concurrency \\ nil) do
    {graph, end_job} = build_workflow_graph(workflow)
    exec_async_workflow(graph, end_job, max_concurrency)
  end

  @spec await(Exec.t(), timeout()) :: await_result()
  def await(%Exec{graph: graph, task: workflow_task}, timeout \\ :infinity) do
    res =
      case Task.yield(workflow_task, timeout) || Task.shutdown(workflow_task) do
        nil -> :timeout
        {:ok, workflow_status} -> workflow_status
      end

    :digraph.delete(graph)

    res
  end

  @spec build_workflow_graph(Dask.t()) :: {:digraph.graph(), Job.t()}
  defp build_workflow_graph(%Dask{jobs: jobs}) do
    graph = :digraph.new([:acyclic])

    Enum.each(jobs, fn {_job_id, %Job{} = job} ->
      :digraph.add_vertex(graph, job, to_string(job.id))
    end)

    Enum.each(jobs, fn {_job_id, %Job{} = job} ->
      Enum.each(job.downstream_jobs, fn downstream_job_id ->
        add_edge(graph, job, jobs[downstream_job_id])
      end)
    end)

    roots = Enum.filter(:digraph.vertices(graph), &(:digraph.in_degree(graph, &1) == 0))
    leafs = Enum.filter(:digraph.vertices(graph), &(:digraph.out_degree(graph, &1) == 0))

    start_job = %Job{
      id: start_job_id(),
      fun: fn _, _ -> :ok end,
      timeout: :infinity,
      downstream_jobs: MapSet.new(),
      on_exit: fn _, _, _, _ -> :ok end
    }

    end_job = %Job{
      id: end_job_id(),
      fun: fn _, upstream_results -> upstream_results end,
      timeout: :infinity,
      downstream_jobs: MapSet.new(),
      on_exit: fn _, _, _, _ -> :ok end
    }

    :digraph.add_vertex(graph, start_job, to_string(start_job.id))
    :digraph.add_vertex(graph, end_job, to_string(end_job.id))

    Enum.each(roots, &:digraph.add_edge(graph, start_job, &1))
    Enum.each(leafs, &:digraph.add_edge(graph, &1, end_job))

    {graph, end_job}
  end

  @spec add_edge(:digraph.graph(), Job.t(), Job.t()) :: :ok
  defp add_edge(graph, %Job{} = upstream_job, %Job{} = downstream_job) do
    case :digraph.add_edge(graph, upstream_job, downstream_job) do
      {:error, {:bad_edge, path}} ->
        cycle_path = Enum.map_join(path, " -> ", & &1.id)

        raise Error, "Cycle detected: #{cycle_path}"

      {:error, {:bad_vertex, %Job{id: job_id}}} ->
        # coveralls-ignore-start
        raise Error, "Bad job: #{inspect(job_id)}"

      # coveralls-ignore-end

      _ ->
        :ok
    end
  end

  @spec exec_async_workflow(:digraph.graph(), Job.t(), Limiter.max_concurrency()) :: Dask.Exec.t()
  defp exec_async_workflow(graph, %Job{} = end_job, max_concurrency) do
    %Exec{graph: graph, task: Task.async(fn -> Exec.exec(graph, end_job, max_concurrency) end)}
  end
end
