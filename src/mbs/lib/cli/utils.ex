defmodule MBS.CLI.Utils do
  @moduledoc false

  alias MBS.Manifest.BuildDeploy

  @typep manifests_deep_list :: [BuildDeploy.Type.t() | manifests_deep_list()]

  @spec filter_manifest_by_id(String.t(), [String.t()]) :: boolean()
  def filter_manifest_by_id(_id, []), do: true
  def filter_manifest_by_id(id, target_ids), do: id in target_ids

  @spec transitive_dependencies_closure([BuildDeploy.Type.t()], [String.t()]) :: [BuildDeploy.Type.t()]
  def transitive_dependencies_closure(manifests, []), do: manifests

  def transitive_dependencies_closure(manifests, target_ids) do
    target_manifests = Enum.filter(manifests, &filter_manifest_by_id(&1.id, target_ids))

    target_manifests
    |> Enum.map(&collect_deps/1)
    |> List.flatten()
    |> Enum.uniq_by(& &1.id)
  end

  @spec collect_deps(BuildDeploy.Type.t()) :: manifests_deep_list()
  defp collect_deps(manifest) do
    case manifest do
      %BuildDeploy.Component{toolchain: toolchain, dependencies: dependencies} ->
        [manifest, toolchain | Enum.map(dependencies, &collect_deps/1)]

      %BuildDeploy.Toolchain{} ->
        [manifest]
    end
  end
end
