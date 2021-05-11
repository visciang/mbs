defmodule MBS.Workflow.Job.RunDeploy do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Docker, Toolchain}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t()) :: Job.fun()
  def fun(%Config.Data{}, %BuildDeploy.Toolchain{id: id, dir: toolchain_dir}) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      {report_status, checksum} =
        with {:ok, checksum} <- build_checksum(toolchain_dir),
             {:image_exists, false, checksum} <- {:image_exists, Docker.image_exists(id, checksum), checksum},
             path_tar_gz = Path.join(toolchain_dir, "#{id}.tar.gz"),
             :ok <- Docker.image_load(path_tar_gz, job_id) do
          {Reporter.Status.ok(), checksum}
        else
          {:image_exists, true, checksum} ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()
      Reporter.job_report(job_id, report_status, checksum, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(
        %Config.Data{},
        %BuildDeploy.Component{dir: component_dir, toolchain: %BuildDeploy.Toolchain{dir: toolchain_dir}} = component
      ) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      {report_status, deploy_checksum} =
        with {:ok, build_checksum} <- build_checksum(component_dir),
             {:ok, toolchain_checksum} <- build_checksum(toolchain_dir),
             deploy_checksum = Job.Utils.deploy_checksum(component, build_checksum, upstream_results),
             component = put_in(component.toolchain.checksum, toolchain_checksum),
             {:ok, envs} <- Toolchain.RunDeploy.up(component, build_checksum),
             :ok <- Toolchain.RunDeploy.exec(component, envs) do
          {Reporter.Status.ok(), deploy_checksum}
        else
          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()
      Reporter.job_report(job_id, report_status, deploy_checksum, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      %Job.FunResult{checksum: deploy_checksum}
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

  @spec build_checksum(Path.t()) :: {:ok, String.t()} | {:error, String.t()}
  def build_checksum(dir) do
    metadata_path = Path.join(dir, Const.release_metadata_filename())

    if File.exists?(metadata_path) do
      checksum =
        metadata_path
        |> File.read!()
        |> Jason.decode!()
        |> Map.fetch!("checksum")

      {:ok, checksum}
    else
      {:error, "Can't find #{metadata_path}"}
    end
  end
end
