defmodule MBS.CLI.Utils do
  @moduledoc false

  alias MBS.{Const, Manifest, Utils}
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

  @spec find_release(Path.t()) :: Manifest.Release.t()
  def find_release(release_dir) do
    release_metadata_path = Path.join(release_dir, Const.release_metadata())

    unless File.exists?(release_metadata_path) do
      error_message = "Can't find release #{release_metadata_path}"
      Utils.halt(error_message)
    end

    release_metadata_map =
      release_metadata_path
      |> File.read!()
      |> Jason.decode!()

    %Manifest.Release{
      id: Map.fetch!(release_metadata_map, "id"),
      checksum: Map.fetch!(release_metadata_map, "checksum"),
      metadata: Map.fetch!(release_metadata_map, "metadata")
    }
  end

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
