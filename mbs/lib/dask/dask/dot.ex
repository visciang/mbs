defmodule Dask.Dot do
  @moduledoc """
  Dask to dot (https://graphviz.org/)
  """
  alias Dask.Job

  @doc """
  Export a workflow to dot graph.
  """
  @spec export(Dask.t()) :: iodata()
  def export(%Dask{jobs: jobs}) do
    ["strict digraph {\n", Enum.flat_map(Map.values(jobs), &job_edge/1), "}\n"]
  end

  @spec job_edge(Job.t()) :: [String.t()]
  defp job_edge(%Job{} = job) do
    if MapSet.size(job.downstream_jobs) == 0 do
      [~s/#{inspect(job.id)}\n/]
    else
      Enum.map(job.downstream_jobs, fn downstream_job_id ->
        ~s/#{inspect(job.id)} -> #{inspect(downstream_job_id)}\n/
      end)
    end
  end
end
