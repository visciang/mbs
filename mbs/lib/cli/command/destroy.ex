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

  @spec run(Command.Destroy.t(), Config.Data.t()) :: :ok | :error | :timeout
  def run(%Command.Destroy{release_id: release_id}, %Config.Data{} = config) do
    {release, release_dir} = Release.get_release(release_id)

    IO.puts("\nDestroying deploy release '#{release.id}' (#{release.checksum})\n")

    manifests = BuildDeploy.find_all(:deploy, config, release_dir)

    with {:ok, _} <- load_toolchains(config, manifests),
         {:ok, _} <- run_destroy(config, manifests) do
      :ok
    else
      {:error, _} -> :error
      :timeout -> :timeout
    end
  end

  @spec load_toolchains(Config.Data.t(), [BuildDeploy.Type.t()]) :: Dask.await_result()
  defp load_toolchains(%Config.Data{} = config, manifests) do
    manifests_toolchains = Enum.filter(manifests, &match?(%BuildDeploy.Toolchain{}, &1))
    run_destroy(config, manifests_toolchains)
  end

  @spec run_destroy(Config.Data.t(), [BuildDeploy.Type.t()]) :: Dask.await_result()
  defp run_destroy(%Config.Data{} = config, manifests) do
    dask =
      Workflow.workflow(
        manifests,
        config,
        &Workflow.Job.DestroyDeploy.fun/2,
        &Workflow.default_job_on_exit/3,
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
