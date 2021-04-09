defmodule MBS.CLI.Utils do
  @moduledoc false

  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  @type manifest_map :: %{String.t() => BuildDeploy.Type.t()}
  @type manifest_set :: MapSet.t(BuildDeploy.Type.t())

  @spec filter_manifest_by_id(String.t(), [String.t()]) :: boolean()
  def filter_manifest_by_id(_id, []), do: true
  def filter_manifest_by_id(id, target_ids), do: id in target_ids

  @spec transitive_dependencies_closure([BuildDeploy.Type.t()], [String.t()]) :: [BuildDeploy.Type.t()]
  def transitive_dependencies_closure(manifests, []), do: manifests

  def transitive_dependencies_closure(manifests, target_ids) do
    manifests_map = Map.new(manifests, &{&1.id, &1})
    target_manifests = Enum.filter(manifests, &filter_manifest_by_id(&1.id, target_ids))

    target_manifests
    |> Enum.flat_map(&_transitive_dependencies_closure(&1, manifests_map))
    |> Enum.uniq()
  end

  @spec _transitive_dependencies_closure(BuildDeploy.Type.t(), manifest_map(), manifest_set()) :: manifest_set()
  defp _transitive_dependencies_closure(target_manifest, manifests_map, visited_manifests \\ MapSet.new()) do
    if MapSet.member?(visited_manifests, target_manifest) do
      visited_manifests
    else
      _transitive_dependencies_closure_visit(target_manifest, manifests_map, visited_manifests)
    end
  end

  @spec _transitive_dependencies_closure_visit(BuildDeploy.Type.t(), manifest_map(), manifest_set()) :: manifest_set()
  defp _transitive_dependencies_closure_visit(target_manifest, manifests_map, visited_manifests) do
    case target_manifest do
      %BuildDeploy.Component{} = component ->
        dependencies = Job.Utils.component_dependencies(component)

        Enum.reduce(dependencies, visited_manifests, fn
          dependency_id, visited_manifests ->
            dependency_manifest = Map.fetch!(manifests_map, dependency_id)
            visited_manifests = MapSet.put(visited_manifests, target_manifest)

            MapSet.union(
              visited_manifests,
              _transitive_dependencies_closure(dependency_manifest, manifests_map, visited_manifests)
            )
        end)

      %BuildDeploy.Toolchain{} ->
        MapSet.put(visited_manifests, target_manifest)
    end
  end
end
