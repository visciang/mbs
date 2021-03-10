defmodule MBS.CLI.Command.Run do
  @moduledoc false
  defstruct [:targets, :logs]

  @type t :: %__MODULE__{
          targets: [String.t()],
          logs: boolean()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Run do
  alias MBS.CLI.{Command, Reporter}
  alias MBS.{CLI, Config, Manifest, Utils, Workflow}

  @spec run(Command.Run.t(), Config.Data.t(), Reporter.t()) :: Dask.await_result()
  def run(%Command.Run{targets: target_ids, logs: logs_enabled}, %Config.Data{} = config, reporter) do
    dask =
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(
        config,
        reporter,
        &Workflow.Job.run_fun(&1, &2, &3, logs_enabled),
        &Workflow.Job.run_fun_on_exit(&1, &2, &3, reporter)
      )

    dask =
      try do
        Dask.async(dask, config.parallelism)
      rescue
        error in [Dask.Error] ->
          Utils.halt(error.message)
      end

    Dask.await(dask)
  end
end
