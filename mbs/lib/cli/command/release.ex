defmodule MBS.CLI.Command.Release do
  @moduledoc false
  defstruct [:targets, :tag, :output_dir]

  @type t :: %__MODULE__{
          targets: [String.t()],
          tag: String.t(),
          output_dir: Path.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Release do
  alias MBS.CLI.{Command, Reporter}
  alias MBS.{Checksum, CLI, Config, Manifest, Utils, Workflow}

  @spec run(Command.Release.t(), Config.Data.t(), Reporter.t()) :: Dask.await_result()
  def run(%Command.Release{tag: tag, targets: target_ids, output_dir: output_dir}, %Config.Data{} = config, reporter) do
    File.mkdir_p!(output_dir)

    manifests =
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)

    dask =
      manifests
      |> Workflow.workflow(
        config,
        reporter,
        &Workflow.Job.release_fun(&1, &2, &3, output_dir),
        &Workflow.Job.run_fun_on_exit(&1, &2, &3, reporter)
      )

    dask =
      try do
        Dask.async(dask, config.parallelism)
      rescue
        error in [Dask.Error] ->
          Utils.halt(error.message)
      end

    res = Dask.await(dask)

    release_manifest(manifests, tag, output_dir)

    res
  end

  defp release_manifest(manifests, tag, output_dir) do
    {commit, 0} = System.cmd("git", ["rev-parse", "HEAD"])

    release_manifest = %{
      tag: tag,
      commit: commit |> String.trim(),
      checksum: release_checksum(manifests, output_dir)
    }

    release_manifest_path = Path.join(output_dir, "manifest.json")
    File.write!(release_manifest_path, Jason.encode!(release_manifest, pretty: true))
  end

  defp release_checksum(manifests, output_dir) do
    manifests
    |> Enum.map(fn %{id: id} ->
      Path.join([output_dir, id, "manifest.json"])
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("checksum")
    end)
    |> Enum.join()
    |> Checksum.checksum()
  end
end
