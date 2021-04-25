defmodule MBS.CLI.Command.RunDeploy do
  @moduledoc false
  defstruct [:release_id, :force]

  @type t :: %__MODULE__{
          release_id: String.t(),
          force: boolean()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.RunDeploy do
  alias MBS.CLI.Command
  alias MBS.{Config, Utils, Workflow}
  alias MBS.Manifest.{BuildDeploy, Release}

  @spec run(Command.RunDeploy.t(), Config.Data.t()) :: Command.on_run()
  def run(%Command.RunDeploy{release_id: release_id, force: force}, %Config.Data{} = config) do
    {release, release_dir} = Release.get_release(release_id)

    IO.puts("\nRunning release '#{release.id}' deploy (#{release.checksum})\n")

    dask =
      BuildDeploy.find_all(:deploy, config, release_dir)
      |> Workflow.workflow(config, &Workflow.Job.RunDeploy.fun(&1, &2, force), &Workflow.Job.OnExit.fun/2)

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
