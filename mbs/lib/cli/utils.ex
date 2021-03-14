defmodule MBS.CLI.Utils do
  @moduledoc false

  alias MBS.Manifest

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

  defp do_transitive_dependencies_closure(target_manifest, manifests_map, visited_manifests \\ MapSet.new()) do
    if MapSet.member?(visited_manifests, target_manifest) do
      visited_manifests
    else
      case target_manifest do
        %Manifest.Component{dependencies: dependencies, toolchain: %Manifest.Toolchain{id: toolchain_id}} ->
          Enum.reduce([toolchain_id | dependencies], visited_manifests, fn
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
