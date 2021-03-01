defmodule MBS.Workflow do
  @moduledoc """
  Workflow DAG builder
  """

  alias MBS.{Config, Manifest, Utils}

  require MBS.CLI.Reporter.Status

  def workflow(manifests, %Config.Data{} = config, reporter, job_fun) do
    workflow =
      Enum.reduce(manifests, Dask.new(), fn manifest, workflow ->
        Dask.job(workflow, manifest.id, job_fun.(reporter, config, manifest))
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
