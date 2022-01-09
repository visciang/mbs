defmodule MBS.Workflow.Job.RunDeploy do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Docker, Toolchain}
  alias MBS.Manifest.{BuildDeploy, Release}
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t(), Release.Type.t()) :: Job.fun()
  def fun(
        %Config.Data{},
        %BuildDeploy.Toolchain{id: id, dir: toolchain_dir},
        %Release.Type{build_manifests: build_manifests}
      ) do
    build_checksum_map = Map.new(build_manifests, &{&1.id, &1.checksum})

    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      {:ok, checksum} = Map.fetch(build_checksum_map, id)

      {report_status, checksum} =
        with {:image_exists, false, checksum} <- {:image_exists, Docker.image_exists(id, checksum), checksum},
             path_tar_gz = Path.join(toolchain_dir, "#{id}.tar.gz"),
             :ok <- Docker.image_load(path_tar_gz, job_id) do
          {Reporter.Status.ok(), checksum}
        else
          {:image_exists, true, checksum} ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason, nil), nil}
        end

      end_time = Reporter.time()
      Reporter.job_report(job_id, report_status, checksum, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      %Job.FunResult{}
    end
  end

  def fun(
        %Config.Data{},
        %BuildDeploy.Component{
          id: component_id,
          checksum: deploy_checksum,
          toolchain: %BuildDeploy.Toolchain{id: toolchain_id}
        } = component,
        %Release.Type{id: release_id, build_manifests: build_manifests}
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      work_dir = Path.join(Release.release_dir(release_id), component_id)

      build_checksum_map = Map.new(build_manifests, &{&1.id, &1.checksum})
      {:ok, build_checksum} = Map.fetch(build_checksum_map, component_id)
      {:ok, toolchain_checksum} = Map.fetch(build_checksum_map, toolchain_id)

      component = put_in(component.toolchain.checksum, toolchain_checksum)

      {report_status, deploy_checksum} =
        with {:ok, envs} <- Toolchain.RunDeploy.up(work_dir, component, build_checksum),
             :ok <- Toolchain.RunDeploy.exec(component, envs) do
          {Reporter.Status.ok(), deploy_checksum}
        else
          {:error, reason} ->
            {Reporter.Status.error(reason, nil), nil}
        end

      end_time = Reporter.time()
      Reporter.job_report(job_id, report_status, deploy_checksum, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      %Job.FunResult{}
    end
  end

  @spec fun_on_exit(Config.Data.t(), BuildDeploy.Type.t()) :: Dask.Job.on_exit()
  def fun_on_exit(%Config.Data{} = config, %BuildDeploy.Toolchain{} = toolchain) do
    Job.OnExit.fun(config, toolchain)
  end

  def fun_on_exit(%Config.Data{} = config, %BuildDeploy.Component{id: id} = component) do
    job_on_exit = Job.OnExit.fun(config, component)

    fn _job_id, upstream_results, job_exec_result, elapsed_time_ms ->
      if Job.Common.job_started?(job_exec_result) do
        Toolchain.RunDeploy.down(component)
        job_on_exit.(id, upstream_results, job_exec_result, elapsed_time_ms)
      end
    end
  end
end
