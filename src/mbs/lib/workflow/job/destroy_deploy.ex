defmodule MBS.Workflow.Job.DestroyDeploy do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Toolchain}
  alias MBS.Manifest.{BuildDeploy, Release}
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t(), Release.Type.t()) :: Job.fun()
  def fun(
        %Config.Data{} = conf,
        %BuildDeploy.Toolchain{} = toolchain,
        %Release.Type{} = release
      ) do
    Job.RunDeploy.fun(conf, toolchain, release)
  end

  def fun(
        %Config.Data{},
        %BuildDeploy.Component{id: component_id, toolchain: %BuildDeploy.Toolchain{id: toolchain_id}} = component,
        %Release.Type{id: release_id, build_manifests: build_manifests}
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      work_dir = Path.join(Release.release_dir(release_id), component_id)

      build_checksum_map = Map.new(build_manifests, &{&1.id, &1.checksum})
      {:ok, build_checksum} = Map.fetch(build_checksum_map, component_id)
      {:ok, toolchain_checksum} = Map.fetch(build_checksum_map, toolchain_id)

      component = put_in(component.toolchain.checksum, toolchain_checksum)

      report_status =
        with {:ok, envs} <- Toolchain.RunDeploy.up(work_dir, component, build_checksum),
             :ok <- Toolchain.RunDeploy.exec_destroy(component, envs) do
          Reporter.Status.ok()
        else
          {:error, reason} ->
            Reporter.Status.error(reason, nil)
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, nil, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{}
    end
  end

  @spec fun_on_exit(Config.Data.t(), BuildDeploy.Type.t()) :: Dask.Job.on_exit()
  def fun_on_exit(config, toolchain) do
    Job.RunDeploy.fun_on_exit(config, toolchain)
  end
end
