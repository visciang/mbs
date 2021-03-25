defmodule MBS.Workflow.Job.Utils do
  @moduledoc """
  Workflow job utils
  """

  alias MBS.Checksum
  alias MBS.Docker
  alias MBS.Manifest.{Component, Target, Toolchain, Type}
  alias MBS.Workflow.Job

  @spec checksum(Path.t(), [Path.t()], %{String.t() => String.t()}) :: String.t()
  def checksum(component_dir, files, upstream_checksums) do
    component_checksum = Checksum.files_checksum(files, component_dir)
    checksum(component_checksum, upstream_checksums)
  end

  @spec checksum(String.t(), %{String.t() => String.t()}) :: String.t()
  def checksum(component_checksum, upstream_checksums) do
    dependencies_checksums =
      upstream_checksums
      |> Enum.sort_by(fn {dependency_name, _} -> dependency_name end)
      |> Enum.map(fn {_dependency_name, dependency_checksum} -> dependency_checksum end)

    [component_checksum | dependencies_checksums]
    |> Enum.join()
    |> Checksum.checksum()
  end

  @spec upstream_results_to_checksums_map(%{String.t() => Job.FunResult.t()}) :: %{String.t() => String.t()}
  def upstream_results_to_checksums_map(upstream_results) do
    Map.new(upstream_results, fn
      {dependency_name, %Job.FunResult{checksum: dependency_checksum}} ->
        {dependency_name, dependency_checksum}
    end)
  end

  @spec filter_upstream_results(Dask.Job.upstream_results(), [String.t()]) :: Dask.Job.upstream_results()
  def filter_upstream_results(upstream_results, job_dependencies) do
    upstream_results
    |> Enum.filter(fn {dependency_name, _} -> dependency_name in job_dependencies end)
    |> Map.new()
  end

  @spec assert_targets([String.t()], String.t()) :: :ok | {:error, String.t()}
  def assert_targets([], _checksum), do: :ok

  def assert_targets(targets, checksum) do
    missing_targets =
      Enum.filter(targets, fn
        %Target{type: :file, target: target} ->
          not File.exists?(target)

        %Target{type: :docker, target: target} ->
          not Docker.image_exists(target, checksum)
      end)

    if length(missing_targets) != 0 do
      {:error, "Missing targets #{inspect(missing_targets)}"}
    else
      :ok
    end
  end

  @spec component_dependencies(Type.t()) :: [String.t()]
  def component_dependencies(%Component{toolchain: %Toolchain{id: toolchain_id}, dependencies: dependencies}) do
    [toolchain_id | dependencies]
  end

  def component_dependencies(%Toolchain{}) do
    []
  end
end
