defmodule MBS.Workflow.Job.RunDeploy do
  @moduledoc """
  Workflow job logic for "deploy run" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Docker, Toolchain}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t(), boolean()) :: Job.fun()
  def fun(%Config.Data{}, %BuildDeploy.Toolchain{id: id, dir: toolchain_dir}, _force) do
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

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(
        %Config.Data{},
        %BuildDeploy.Component{dir: component_dir, toolchain: %BuildDeploy.Toolchain{dir: toolchain_dir}} = component,
        _force
      ) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      {report_status, deploy_checksum} =
        with {:ok, build_checksum} <- build_checksum(component_dir),
             {:ok, toolchain_checksum} <- build_checksum(toolchain_dir),
             deploy_checksum = Job.Utils.deploy_checksum(component, build_checksum, upstream_results),
             component = put_in(component.toolchain.checksum, toolchain_checksum),
             :ok <- Toolchain.exec_deploy(component, build_checksum) do
          {Reporter.Status.ok(), deploy_checksum}
        else
          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      # define "deploy state" (environment should be supported)
      # Check deploy state to determine if the component should be deployed
      # [execute ...]
      # Update deploy state

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, deploy_checksum, end_time - start_time)

      # unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
      unless match?(Reporter.Status.ok(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: deploy_checksum}
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
