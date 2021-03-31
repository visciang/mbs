defmodule MBS.CLI.Command.Destroy do
  @moduledoc false
  defstruct [:release_id]

  @type t :: %__MODULE__{
          release_id: String.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Destroy do
  alias MBS.CLI.Command
  alias MBS.{CLI, Config, Const, Manifest, Utils, Workflow}

  @spec run(Command.Destroy.t(), Config.Data.t()) :: :ok | :error | :timeout
  def run(%Command.Destroy{release_id: release_id}, %Config.Data{} = config) do
    release_dir = Path.join(Const.releases_dir(), release_id)
    release = CLI.Utils.find_release(release_dir)

    IO.puts("\nDestroying deploy release '#{release.id}' (#{release.checksum})\n")

    manifests = Manifest.find_all(:deploy, release_dir, false)

    with {:ok, _} <- load_toolchains(config, manifests),
         {:ok, _} <- run_destroy(config, manifests) do
      :ok
    else
      {:error, _} -> :error
      :timeout -> :timeout
    end
  end

  defp load_toolchains(%Config.Data{} = config, manifests) do
    manifests_toolchains = Enum.filter(manifests, &match?(%Manifest.Toolchain{}, &1))
    run_destroy(config, manifests_toolchains)
  end

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
