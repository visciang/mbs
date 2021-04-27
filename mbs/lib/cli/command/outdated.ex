defmodule MBS.CLI.Command.Outdated do
  @moduledoc false
  defstruct []

  @type t :: %__MODULE__{}
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Outdated do
  alias MBS.CLI.Command
  alias MBS.{Config, Utils, Workflow}
  alias MBS.Manifest.BuildDeploy

  @spec run(Command.Outdated.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.Outdated{}, %Config.Data{} = config, cwd) do
    dask =
      BuildDeploy.find_all(:build, config, cwd)
      |> Workflow.workflow(config, &Workflow.Job.Outdated.fun/2)

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
