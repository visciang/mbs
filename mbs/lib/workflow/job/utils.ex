defmodule MBS.Workflow.Job.Utils do
  @moduledoc """
  Workflow job utils
  """

  alias MBS.Checksum
  alias MBS.Docker
  alias MBS.Manifest.Target
  alias MBS.Workflow.Job.JobFunResult

  def checksum(files, upstream_results) do
    files_checksum = Checksum.files_checksum(files)

    dependencies_checksums =
      upstream_results
      |> Enum.sort_by(fn {dependency_name, _} -> dependency_name end)
      |> Enum.map(fn {_dependency_name, %JobFunResult{checksum: dependency_checksum}} -> dependency_checksum end)

    [files_checksum | dependencies_checksums]
    |> Enum.join()
    |> Checksum.checksum("")
  end

  def filter_upstream_results(upstream_results, job_dependencies) do
    Enum.filter(upstream_results, fn {dependency_name, _} -> dependency_name in job_dependencies end)
    |> Map.new()
  end

  def assert_targets([], _checksum), do: :ok

  def assert_targets(targets, checksum) do
    missing_targets =
      Enum.filter(targets, fn
        %Target{type: "file", target: target} ->
          not File.exists?(target)

        %Target{type: "docker", target: target} ->
          not Docker.image_exists(target, checksum)
      end)

    if length(missing_targets) != 0 do
      {:error, "Missing targets #{inspect(missing_targets)}"}
    else
      :ok
    end
  end
end
