defmodule MBS.Manifest.BuildDeploy.Workflow do
  @moduledoc false

  alias MBS.{Config, Utils}
  alias MBS.Manifest.BuildDeploy.Type

  @type to_struct_fun :: (Type.type(), map(), %{String.t() => Type.t()}, Config.Data.files_profiles() -> Type.t())

  @spec to_type([map()], to_struct_fun(), Type.type(), Config.Data.files_profiles()) :: [Type.t()]
  def to_type(manifests, to_struct_fun, type, files_profile) do
    workflow = Enum.reduce(manifests, Dask.new(), to_type_fun(to_struct_fun, type, files_profile))
    workflow = Enum.reduce(manifests, workflow, &to_type_deps_reducer/2)

    {:ok, result} =
      workflow
      |> Dask.async()
      |> Dask.await()

    result
    |> Map.values()
    |> Utils.merge_maps()
    |> Map.values()
  end

  @spec to_type_fun(to_struct_fun(), Type.type(), Config.Data.files_profiles()) :: Dask.Job.fun()
  def to_type_fun(to_struct_fun, type, files_profile) do
    fn manifest, workflow ->
      dask_job_fun = fn id, upstream_res ->
        upstream_components_maps =
          upstream_res
          |> Map.delete(Dask.start_job_id())
          |> Map.values()

        upstream_components_map = merge_maps(upstream_components_maps)

        upstream_components_map
        |> Map.put(id, to_struct_fun.(type, manifest, upstream_components_map, files_profile))
      end

      Dask.job(workflow, manifest["id"], dask_job_fun)
    end
  end

  @spec to_type_deps_reducer(map(), Dask.t()) :: Dask.t()
  defp to_type_deps_reducer(manifest, workflow) do
    case manifest do
      %{"__schema__" => "component", "component" => component} = manifest ->
        try do
          Dask.depends_on(workflow, manifest["id"], [component["toolchain"] | component["dependencies"]])
        rescue
          error in [Dask.Error] ->
            Utils.halt("Error in #{manifest["dir"]}:\n  #{error.message}")
        end

      %{"__schema__" => "toolchain"} ->
        workflow
    end
  end

  @spec merge_maps([map()]) :: map()
  defp merge_maps([]), do: %{}
  defp merge_maps(upstream_components_maps), do: Utils.merge_maps(upstream_components_maps)
end
