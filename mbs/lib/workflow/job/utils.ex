defmodule MBS.Workflow.Job.Utils do
  @moduledoc """
  Workflow job utils
  """

  alias MBS.{Checksum, Const}
  alias MBS.Manifest.BuildDeploy.{Component, Toolchain, Type}
  alias MBS.Workflow.Job

  @spec build_checksum(Component.t(), Job.upstream_results()) :: String.t()
  def build_checksum(%Component{dir: component_dir, files: files} = component, upstream_results) do
    dependencies = component_dependencies(component)
    upstream_results = filter_upstream_results(upstream_results, dependencies)
    upstream_checksums_map = upstream_results_to_checksums_map(upstream_results)
    checksum(component_dir, files, upstream_checksums_map)
  end

  @spec build_checksum2(Component.t(), %{String.t() => String.t()}) :: String.t()
  def build_checksum2(%Component{dir: component_dir, files: files} = component, upstream_checksums) do
    dependencies = component_dependencies(component)
    upstream_checksums = filter_upstream_results(upstream_checksums, dependencies)
    checksum(component_dir, files, upstream_checksums)
  end

  @spec deploy_checksum(Component.t(), String.t(), Job.upstream_results()) :: String.t()
  def deploy_checksum(%Component{dir: component_dir} = component, build_checksum, upstream_results) do
    dependencies = component_dependencies(component)
    upstream_results = filter_upstream_results(upstream_results, dependencies)
    upstream_checksums_map = upstream_results_to_checksums_map(upstream_results)

    deploy_manifest_path = Path.join(component_dir, Const.manifest_deploy_filename())
    deploy_partial_checksum = checksum(component_dir, [deploy_manifest_path], upstream_checksums_map)

    [build_checksum, deploy_partial_checksum]
    |> Enum.join()
    |> Checksum.checksum()
  end

  @spec filter_upstream_results(Dask.Job.upstream_results(), [String.t()]) :: Dask.Job.upstream_results()
  def filter_upstream_results(upstream_results, job_dependencies) do
    upstream_results
    |> Enum.filter(fn {dependency_name, _} -> dependency_name in job_dependencies end)
    |> Map.new()
  end

  @spec component_dependencies(Type.t()) :: [String.t()]
  def component_dependencies(%Toolchain{}), do: []

  def component_dependencies(%Component{toolchain: %Toolchain{id: toolchain_id}, dependencies: dependencies}) do
    [toolchain_id | dependencies]
  end

  @spec checksum(Path.t(), [Path.t()], %{String.t() => String.t()}) :: String.t()
  defp checksum(component_dir, files, upstream_checksums) do
    component_checksum = Checksum.files_checksum(files, component_dir)
    checksum(component_checksum, upstream_checksums)
  end

  @spec checksum(String.t(), %{String.t() => String.t()}) :: String.t()
  defp checksum(component_checksum, upstream_checksums) do
    dependencies_checksums =
      upstream_checksums
      |> Enum.sort_by(fn {dependency_name, _} -> dependency_name end)
      |> Enum.map(fn {_dependency_name, dependency_checksum} -> dependency_checksum end)

    [component_checksum | dependencies_checksums]
    |> Enum.join()
    |> Checksum.checksum()
  end

  @spec upstream_results_to_checksums_map(Job.upstream_results()) :: %{String.t() => String.t()}
  defp upstream_results_to_checksums_map(upstream_results) do
    Map.new(upstream_results, fn
      {dependency_name, %Job.FunResult{checksum: dependency_checksum}} ->
        {dependency_name, dependency_checksum}
    end)
  end
end
