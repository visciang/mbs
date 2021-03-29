defmodule MBS.Workflow.Job.Checksums do
  @moduledoc """
  Workflow job logic for "checksums" command
  """

  alias MBS.{Config, Manifest, Utils}
  alias MBS.Workflow.Job

  @type fun :: (String.t(), Dask.Job.upstream_results() -> %{String.t() => String.t()})

  @spec fun(Config.Data.t(), Manifest.Type.t()) :: fun()
  def fun(%Config.Data{}, %Manifest.Toolchain{id: id, checksum: checksum}) do
    fn _job_id, %{__start_job__: :ok} ->
      %{id => checksum}
    end
  end

  def fun(%Config.Data{}, %Manifest.Component{id: id} = component) do
    fn _job_id, upstream_results ->
      upstream_checksums = upstream_results |> Map.values() |> Utils.merge_maps()
      checksum = Job.Utils.build_checksum2(component, upstream_checksums)
      Map.put(upstream_checksums, id, checksum)
    end
  end
end
