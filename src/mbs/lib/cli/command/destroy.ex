defmodule MBS.CLI.Command.Destroy do
  @moduledoc false

  defstruct [:release_id]

  @type t :: %__MODULE__{
          release_id: String.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Destroy do
  alias MBS.CLI.Command
  alias MBS.{Config, Utils, Workflow}
  alias MBS.Manifest.{BuildDeploy, Release}

  @spec run(Command.Destroy.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.Destroy{release_id: release_id}, %Config.Data{} = config, _cwd) do
    release = Release.get_release(release_id)

    IO.puts("\nDestroying deploy release '#{release.id}'\n")

    with {:ok, _} <- load_toolchains(config, release),
         {:ok, _} <- run_destroy(config, release, release.deploy_manifests) do
      :ok
    else
      {:error, _} -> :error
      :timeout -> :timeout
    end
  end

  @spec load_toolchains(Config.Data.t(), Release.Type.t()) :: Dask.await_result()
  defp load_toolchains(%Config.Data{} = config, release) do
    deploy_toolchains_manifests = Enum.filter(release.deploy_manifests, &match?(%BuildDeploy.Toolchain{}, &1))
    run_destroy(config, release, deploy_toolchains_manifests)
  end

  @spec run_destroy(Config.Data.t(), Release.Type.t(), [BuildDeploy.Type.t()]) :: Dask.await_result()
  defp run_destroy(%Config.Data{} = config, release, manifests) do
    dask =
      Workflow.workflow(
        manifests,
        config,
        &Workflow.Job.DestroyDeploy.fun(&1, &2, release),
        &Workflow.Job.DestroyDeploy.fun_on_exit/2,
        :downward
      )

    dask_exec =
      try do
        Dask.async(dask, config.parallelism)
      rescue
        error in [Dask.Error] ->
          Utils.halt(error.message)
      end

    Dask.await(dask_exec)
  end
end
