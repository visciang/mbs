defmodule MBS.Workflow.Job.Checksums do
  @moduledoc """
  Workflow job logic for "checksums" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Manifest}
  alias MBS.Workflow.Job

  require Reporter.Status

  @type fun :: (String.t(), Dask.Job.upstream_results() -> %{String.t() => String.t()})

  @spec fun(Reporter.t(), Config.Data.t(), Manifest.Type.t()) :: fun()
  def fun(_reporter, %Config.Data{}, %Manifest.Toolchain{id: id, checksum: checksum}) do
    fn _job_id, %{__start_job__: :ok} ->
      %{id => checksum}
    end
  end

  def fun(
        _reporter,
        %Config.Data{},
        %Manifest.Component{id: id, dir: component_dir, files: files} = component
      ) do
    fn _job_id, upstream_checksums ->
      dependencies = Job.Utils.component_dependencies(component)

      upstream_checksums = upstream_checksums |> Map.values() |> merge_maps()
      deps_upstream_checksums = Job.Utils.filter_upstream_results(upstream_checksums, dependencies)
      checksum = Job.Utils.checksum(component_dir, files, deps_upstream_checksums)

      Map.put(upstream_checksums, id, checksum)
    end
  end

  defp merge_maps(maps) do
    Enum.reduce(maps, fn map, map_merge -> Map.merge(map_merge, map) end)
  end
end
