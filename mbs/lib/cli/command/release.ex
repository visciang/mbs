defmodule MBS.CLI.Command.Release do
  @moduledoc false
  defstruct [:targets, :id, :output_dir, :metadata]

  @type t :: %__MODULE__{
          targets: [String.t()],
          id: String.t(),
          output_dir: Path.t(),
          metadata: nil | String.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Release do
  alias MBS.CLI.{Command, Reporter}
  alias MBS.{Checksum, CLI, Config, Const, Manifest, Utils, Workflow}

  @spec run(Command.Release.t(), Config.Data.t(), Reporter.t()) :: :ok | :error | :timeout
  def run(
        %Command.Release{id: id, targets: target_ids, output_dir: output_dir, metadata: metadata},
        %Config.Data{} = config,
        reporter
      ) do
    File.mkdir_p!(output_dir)

    build_manifests =
      Manifest.find_all(:build)
      |> CLI.Utils.transitive_dependencies_closure(target_ids)

    deploy_manifests =
      Manifest.find_all(:deploy)
      |> filter_used_toolchains()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)

    validate_deploy_files(build_manifests, deploy_manifests)

    build_checksums_map = build_checksums(target_ids, build_manifests, config, reporter)

    dask =
      deploy_manifests
      |> Workflow.workflow(
        config,
        reporter,
        &Workflow.Job.Release.fun(&1, &2, &3, output_dir, build_checksums_map),
        &Workflow.Job.OnExit.fun(&1, &2, &3, reporter)
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
      write_release_manifest(deploy_manifests, id, output_dir, metadata)
    end

    res
  end

  defp filter_used_toolchains(manifests) do
    # we collect all the toolchains (as part of Manifest.find_all(:deploy))
    # but some of them are not used to run any component deploy
    manifests
    |> Enum.filter(&match?(%Manifest.Component{}, &1))
    |> Enum.flat_map(&[&1, &1.toolchain])
  end

  defp write_release_manifest(manifests, id, output_dir, metadata) do
    release_manifest = %Manifest.Release{
      id: id,
      checksum: release_checksum(manifests, output_dir),
      metadata: metadata
    }

    File.write!(
      Path.join(output_dir, Const.release_metadata()),
      release_manifest |> Map.from_struct() |> Jason.encode!(pretty: true)
    )
  end

  defp release_checksum(manifests, output_dir) do
    manifests
    |> Enum.map(fn %{id: id} ->
      Path.join([output_dir, id, Const.release_metadata()])
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("checksum")
    end)
    |> Enum.join()
    |> Checksum.checksum()
  end

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

  defp build_checksums(target_ids, build_manifests, config, reporter) do
    dask = Workflow.workflow(build_manifests, config, reporter, &Workflow.Job.Checksums.fun/3)

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
        if target_ids == [] do
          Map.values(checksums_map)
        else
          Enum.map(target_ids, &Map.fetch!(checksums_map, &1))
        end
        |> merge_maps()

      err ->
        Utils.halt("Failed build checksums compute\n#{inspect(err)}")
    end
  end

  defp merge_maps(maps) do
    Enum.reduce(maps, fn map, map_merge -> Map.merge(map_merge, map) end)
  end
end
