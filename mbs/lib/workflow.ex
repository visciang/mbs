defmodule MBS.Workflow do
  @moduledoc """
  Workflow DAG builder
  """

  alias MBS.{Config, Manifest, Utils}

  require MBS.CLI.Reporter.Status

  def workflow(manifests, %Config.Data{} = config, reporter, job_fun) do
    workflow =
      Enum.reduce(manifests, Dask.new(), fn %Manifest.Data{} = manifest, workflow ->
        Dask.job(workflow, manifest.name, job_fun.(reporter, config, manifest))
      end)

    Enum.reduce(manifests, workflow, fn %Manifest.Data{} = manifest, workflow ->
      try do
        Dask.depends_on(workflow, manifest.name, manifest.job.dependencies)
      rescue
        error in [Dask.Error] ->
          Utils.halt("Error in#{manifest.dir}:\n  #{error.message}")
      end
    end)
  end
end
