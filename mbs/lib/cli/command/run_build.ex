defmodule MBS.CLI.Command.RunBuild do
  @moduledoc false
  defstruct [:targets]

  @type t :: %__MODULE__{
          targets: [String.t()]
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.RunBuild do
  alias MBS.CLI.Command
  alias MBS.{CLI, Config, Manifest, Utils, Workflow}

  @spec run(Command.RunBuild.t(), Config.Data.t()) :: :ok | :error | :timeout
  def run(%Command.RunBuild{targets: target_ids}, %Config.Data{} = config) do
    dask =
      Manifest.find_all(:build)
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(
        config,
        &Workflow.Job.RunBuild.fun/2,
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
end
