defmodule MBS.CLI.Command.Outdated do
  @moduledoc false
  defstruct []

  @type t :: %__MODULE__{}
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Outdated do
  alias MBS.CLI.{Command, Reporter}
  alias MBS.{Config, Manifest, Utils, Workflow}

  @spec run(Command.Outdated.t(), Config.Data.t(), Reporter.t()) :: Dask.await_result()
  def run(%Command.Outdated{}, %Config.Data{} = config, reporter) do
    dask =
      Manifest.find_all()
      |> Workflow.workflow(config, reporter, &Workflow.Job.outdated_fun/3)

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
