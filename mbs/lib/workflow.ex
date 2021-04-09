defmodule MBS.Workflow do
  @moduledoc """
  Workflow DAG builder
  """

  alias MBS.{Config, Utils}
  alias MBS.Manifest.BuildDeploy

  @spec workflow(
          [BuildDeploy.Type.t()],
          Config.Data.t(),
          (Config.Data.t(), BuildDeploy.Type.t() -> Dask.Job.fun()),
          Dask.Job.on_exit(),
          :upward | :downward
        ) :: Dask.t()
  def workflow(
        manifests,
        %Config.Data{timeout: global_timeout_sec} = config,
        job_fun,
        job_on_exit \\ &default_job_on_exit/3,
        direction \\ :upward
      ) do
    workflow =
      Enum.reduce(manifests, Dask.new(), fn %{timeout: local_timeout_sec} = manifest, workflow ->
        global_timeout_ms = convert_timeout_s_to_ms(global_timeout_sec)
        local_timeout_ms = convert_timeout_s_to_ms(local_timeout_sec)
        timeout_ms = min(global_timeout_ms, local_timeout_ms)

        Dask.job(workflow, manifest.id, job_fun.(config, manifest), timeout_ms, job_on_exit)
      end)

    Enum.reduce(manifests, workflow, fn
      %BuildDeploy.Component{} = component, workflow ->
        try do
          case direction do
            :upward ->
              # run dependencies first
              Dask.depends_on(workflow, component.id, [component.toolchain.id | component.dependencies])

            :downward ->
              # run dependants first
              Dask.depends_on(workflow, [component.toolchain.id | component.dependencies], component.id)
          end
        rescue
          error in [Dask.Error] ->
            Utils.halt("Error in#{component.dir}:\n  #{error.message}")
        end

      %BuildDeploy.Toolchain{}, workflow ->
        workflow
    end)
  end

  def default_job_on_exit(_, _, _), do: :ok

  defp convert_timeout_s_to_ms(:infinity), do: :infinity
  defp convert_timeout_s_to_ms(seconds), do: seconds * 1_000
end
