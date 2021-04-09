defmodule MBS.Workflow.Job.Checksums do
  @moduledoc """
  Workflow job logic for "checksums" command
  """

  alias MBS.{Config, Utils}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  @type fun_result :: %{String.t() => String.t()}
  @type upstream_results :: %{String.t() => fun_result()}
  @type fun :: (String.t(), upstream_results() -> fun_result())

  @spec fun(Config.Data.t(), BuildDeploy.Type.t()) :: fun()
  def fun(%Config.Data{}, %BuildDeploy.Toolchain{id: id, checksum: checksum}) do
    fn _job_id, %{__start_job__: :ok} ->
      %{id => checksum}
    end
  end

  def fun(%Config.Data{}, %BuildDeploy.Component{id: id} = component) do
    fn _job_id, upstream_results ->
      upstream_checksums = upstream_results |> Map.values() |> Utils.merge_maps()
      checksum = Job.Utils.build_checksum2(component, upstream_checksums)
      Map.put(upstream_checksums, id, checksum)
    end
  end
end
