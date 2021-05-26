defmodule MBS.Workflow do
  @moduledoc false

  alias MBS.{Config, Utils}
  alias MBS.Manifest.BuildDeploy

  @spec workflow(
          [BuildDeploy.Type.t()],
          Config.Data.t(),
          (Config.Data.t(), BuildDeploy.Type.t() -> Dask.Job.fun()),
          (Config.Data.t(), BuildDeploy.Type.t() -> Dask.Job.on_exit()),
          :upward | :downward
        ) :: Dask.t()
  def workflow(
        manifests,
        %Config.Data{timeout: global_timeout_sec} = config,
        job_fun,
        job_fun_on_exit \\ &default_job_fun_on_exit/2,
        direction \\ :upward
      ) do
    workflow =
      Enum.reduce(manifests, Dask.new(), fn %{timeout: local_timeout_sec} = manifest, workflow ->
        global_timeout_ms = convert_timeout_s_to_ms(global_timeout_sec)
        local_timeout_ms = convert_timeout_s_to_ms(local_timeout_sec)
        timeout_ms = min(global_timeout_ms, local_timeout_ms)

        Dask.job(workflow, manifest.id, job_fun.(config, manifest), timeout_ms, job_fun_on_exit.(config, manifest))
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
            Utils.halt("Error in #{component.dir}:\n  #{error.message}")
        end

      %BuildDeploy.Toolchain{}, workflow ->
        workflow
    end)
  end

  @spec default_job_fun_on_exit(Config.Data.t(), BuildDeploy.Type.t()) :: Dask.Job.on_exit()
  def default_job_fun_on_exit(_, _) do
    fn _, _, _, _ -> :ok end
  end

  @spec convert_timeout_s_to_ms(timeout()) :: timeout()
  defp convert_timeout_s_to_ms(:infinity), do: :infinity
  defp convert_timeout_s_to_ms(seconds), do: seconds * 1_000
end
