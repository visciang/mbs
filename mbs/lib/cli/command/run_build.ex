defmodule MBS.CLI.Command.RunBuild do
  @moduledoc false
  defstruct [:targets, :force, :sandbox, :force_get_deps]

  @type t :: %__MODULE__{
          targets: [String.t()],
          force: boolean(),
          force_get_deps: boolean(),
          sandbox: boolean()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.RunBuild do
  alias MBS.CLI.Command
  alias MBS.{CLI, Config, Utils, Workflow}
  alias MBS.Manifest.BuildDeploy

  @spec run(Command.RunBuild.t(), Config.Data.t()) :: :ok | :error | :timeout
  def run(
        %Command.RunBuild{targets: target_ids, force: force, force_get_deps: force_get_deps, sandbox: sandbox},
        %Config.Data{} = config
      ) do
    dask =
      BuildDeploy.find_all(:build, config)
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(
        config,
        &Workflow.Job.RunBuild.fun(&1, &2, force, force_get_deps, sandbox),
        &Workflow.Job.RunBuild.fun_on_exit(&1, &2, sandbox)
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
