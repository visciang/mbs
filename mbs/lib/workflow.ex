defmodule MBS.Workflow do
  @moduledoc """
  Workflow DAG builder
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Manifest, Utils}

  require MBS.CLI.Reporter.Status

  @spec workflow(
          [Manifest.t()],
          Config.Data.t(),
          Reporter.t(),
          (Reporter.t(), Config.Data.t(), Manifest.t() -> Dask.Job.fun()),
          Dask.Job.on_exit()
        ) :: Dask.t()
  def workflow(
        manifests,
        %Config.Data{timeout: global_timeout_sec} = config,
        reporter,
        job_fun,
        job_on_exit \\ fn _, _, _ -> :ok end
      ) do
    workflow =
      Enum.reduce(manifests, Dask.new(), fn %{timeout: local_timeout_sec} = manifest, workflow ->
        global_timeout_ms = if global_timeout_sec == :infinity, do: :infinity, else: global_timeout_sec * 1_000
        local_timeout_ms = if local_timeout_sec == :infinity, do: :infinity, else: local_timeout_sec * 1_000

        timeout_ms = min(global_timeout_ms, local_timeout_ms)

        Dask.job(workflow, manifest.id, job_fun.(reporter, config, manifest), timeout_ms, job_on_exit)
      end)

    Enum.reduce(manifests, workflow, fn
      %Manifest.Component{} = component, workflow ->
        try do
          Dask.depends_on(workflow, component.id, [component.toolchain.id | component.dependencies])
        rescue
          error in [Dask.Error] ->
            Utils.halt("Error in#{component.dir}:\n  #{error.message}")
        end

      %Manifest.Toolchain{}, workflow ->
        workflow
    end)
  end
end
