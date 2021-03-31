defmodule MBS.CLI.Command.RunDeploy do
  @moduledoc false
  defstruct [:release_id, :force]

  @type t :: %__MODULE__{
          release_id: [String.t()],
          force: nil | boolean()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.RunDeploy do
  alias MBS.CLI.Command
  alias MBS.{CLI, Config, Const, Manifest, Utils, Workflow}

  @spec run(Command.RunDeploy.t(), Config.Data.t()) :: :ok | :error | :timeout
  def run(%Command.RunDeploy{release_id: release_id, force: force}, %Config.Data{} = config) do
    release_dir = Path.join(Const.releases_dir(), release_id)
    release = CLI.Utils.find_release(release_dir)

    IO.puts("\nRunning release '#{release.id}' deploy (#{release.checksum})\n")

    dask =
      Manifest.find_all(:deploy, release_dir, false)
      |> Workflow.workflow(config, &Workflow.Job.RunDeploy.fun(&1, &2, force), &Workflow.Job.OnExit.fun/3)

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
end
