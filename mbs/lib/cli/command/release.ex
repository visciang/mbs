defmodule MBS.CLI.Command.MakeRelease do
  @moduledoc false
  defstruct [:targets, :id, :output_dir, :metadata]

  @type t :: %__MODULE__{
          targets: [String.t()],
          id: String.t(),
          metadata: nil | String.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.MakeRelease do
  alias MBS.CLI.Command
  alias MBS.{CLI, Config, Const, Manifest, ReleaseManifest, Utils, Workflow}

  @spec run(Command.MakeRelease.t(), Config.Data.t()) :: :ok | :error | :timeout
  def run(
        %Command.MakeRelease{id: id, targets: target_ids, metadata: metadata},
        %Config.Data{} = config
      ) do
    output_dir = Path.join(Const.releases_dir(), id)

    File.mkdir_p!(output_dir)

    deploy_manifests =
      Manifest.find_all(:deploy)
      |> filter_used_toolchains()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)

    build_targets_id = Enum.map(deploy_manifests, & &1.id)

    build_manifests =
      Manifest.find_all(:build)
      |> CLI.Utils.transitive_dependencies_closure(build_targets_id)

    validate_deploy_files(build_manifests, deploy_manifests)

    build_checksums_map = build_checksums(target_ids, build_manifests, config)

    dask =
      deploy_manifests
      |> Workflow.workflow(
        config,
        &Workflow.Job.Release.fun(&1, &2, output_dir, build_checksums_map),
        &Workflow.Job.OnExit.fun/3
      )

    dask_exec =
      try do
        Dask.async(dask, config.parallelism)
      rescue
        error in [Dask.Error] ->
          Utils.halt(error.message)
      end

    res =
      dask_exec
      |> Dask.await()
      |> case do
        {:ok, _} -> :ok
        {:error, _} -> :error
        :timeout -> :timeout
      end

    if res == :ok do
      ReleaseManifest.write(deploy_manifests, id, metadata)
    end

    res
  end

  @spec filter_used_toolchains([Manifest.Type.t()]) :: [Manifest.Type.t()]
  defp filter_used_toolchains(manifests) do
    # we collect all the toolchains (as part of Manifest.find_all(:deploy))
    # but some of them are not used to run any component deploy
    manifests
    |> Enum.filter(&match?(%Manifest.Component{}, &1))
    |> Enum.flat_map(&[&1, &1.toolchain])
  end

  @spec validate_deploy_files([Manifest.Type.t()], [Manifest.Type.t()]) :: :ok
  defp validate_deploy_files(build_manifests, deploy_manifests) do
    build_manifest_targets_map =
      build_manifests
      |> Enum.filter(&match?(%Manifest.Component{}, &1))
      |> Map.new(&{&1.id, MapSet.new(&1.targets)})

    deploy_manifests
    |> Enum.filter(&match?(%Manifest.Component{}, &1))
    |> Enum.each(fn %Manifest.Component{id: id, files: files} ->
      files
      |> MapSet.new()
      |> MapSet.subset?(Map.get(build_manifest_targets_map, id, MapSet.new()))
      |> unless do
        error_message = "Deploy files #{inspect(files)} in component #{id} are not all build targets"
        Utils.halt(error_message)
      end
    end)
  end

  @spec build_checksums([String.t()], [Manifest.Type.t()], Config.Data.t()) :: %{String.t() => String.t()}
  defp build_checksums(_target_ids, build_manifests, config) do
    dask = Workflow.workflow(build_manifests, config, &Workflow.Job.Checksums.fun/2)

    dask_exec =
      try do
        Dask.async(dask, config.parallelism)
      rescue
        error in [Dask.Error] ->
          Utils.halt(error.message)
      end

    dask_exec
    |> Dask.await()
    |> case do
      {:ok, checksums_map} ->
        checksums_map |> Map.values() |> Utils.merge_maps()

      err ->
        Utils.halt("Failed build checksums compute\n#{inspect(err)}")
    end
  end
end
