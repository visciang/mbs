defmodule MBS.CLI.Utils do
  @moduledoc false

  alias MBS.Manifest
  alias MBS.Workflow.Job

  @spec filter_manifest_by_id(String.t(), [String.t()]) :: boolean()
  def filter_manifest_by_id(_id, []), do: true
  def filter_manifest_by_id(id, target_ids), do: id in target_ids

  @spec transitive_dependencies_closure([Manifest.Type.t()], [String.t()]) :: [Manifest.Type.t()]
  def transitive_dependencies_closure(manifests, []), do: manifests

  def transitive_dependencies_closure(manifests, target_ids) do
    manifests_map = Map.new(manifests, &{&1.id, &1})
    target_manifests = Enum.filter(manifests, &filter_manifest_by_id(&1.id, target_ids))

    target_manifests
    |> Enum.flat_map(&do_transitive_dependencies_closure(&1, manifests_map))
    |> Enum.uniq()
  end

  @spec do_transitive_dependencies_closure(
          Manifest.Type.t(),
          %{String.t() => Manifest.Type.t()},
          MapSet.t(Manifest.Type.t())
        ) :: MapSet.t(Manifest.Type.t())
  defp do_transitive_dependencies_closure(target_manifest, manifests_map, visited_manifests \\ MapSet.new()) do
    if MapSet.member?(visited_manifests, target_manifest) do
      visited_manifests
    else
      case target_manifest do
        %Manifest.Component{} = component ->
          dependencies = Job.Utils.component_dependencies(component)

          Enum.reduce(dependencies, visited_manifests, fn
            dependency_id, visited_manifests ->
              dependency_manifest = Map.fetch!(manifests_map, dependency_id)
              visited_manifests = MapSet.put(visited_manifests, target_manifest)

              MapSet.union(
                visited_manifests,
                do_transitive_dependencies_closure(dependency_manifest, manifests_map, visited_manifests)
              )
          end)

        %Manifest.Toolchain{} ->
          MapSet.put(visited_manifests, target_manifest)
      end
    end
  end
end
