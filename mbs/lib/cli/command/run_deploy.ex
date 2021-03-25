defmodule MBS.CLI.Command.RunDeploy do
  @moduledoc false
  defstruct [:release_id]

  @type t :: %__MODULE__{
          release_id: [String.t()]
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.RunDeploy do
  alias MBS.CLI.Command
  alias MBS.{Config, Const, Manifest, Utils, Workflow}

  @spec run(Command.RunDeploy.t(), Config.Data.t()) :: :ok | :error | :timeout
  def run(%Command.RunDeploy{release_id: release_id}, %Config.Data{} = config) do
    release_dir = Path.join(Const.releases_dir(), release_id)

    release = find_release(release_dir)

    IO.puts("\nRunning release '#{release.id}' deploy (#{release.checksum})\n")

    dask =
      Manifest.find_all(:deploy, release_dir, false)
      |> Workflow.workflow(
        config,
        &Workflow.Job.RunDeploy.fun/2,
        &Workflow.Job.OnExit.fun(&1, &2, &3)
      )

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
      {:ok, _} -> :ok
      {:error, _} -> :error
      :timeout -> :timeout
    end
  end

  defp find_release(release_dir) do
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
end
