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
  alias MBS.{CLI, Config, Manifest, Utils, Workflow}

  @spec run(Command.Release.t(), Config.Data.t(), Reporter.t()) :: Dask.await_result()
  def run(%Command.Release{targets: target_ids, output_dir: output_dir}, %Config.Data{} = config, reporter) do
    dask =
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
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

    Dask.await(dask)
  end
end
