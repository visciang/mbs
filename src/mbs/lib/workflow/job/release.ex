defmodule MBS.Workflow.Job.Release do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Config
  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  require Reporter.Status

  @type fun :: (String.t(), Dask.Job.upstream_results() -> :ok)

  @spec fun(Config.Data.t(), BuildDeploy.Type.t(), Path.t(), %{String.t() => String.t()}) :: fun()
  def fun(%Config.Data{} = config, %BuildDeploy.Toolchain{id: id, checksum: checksum}, release_dir, _build_checksums) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      targets_dir = Path.join(release_dir, id)
      target = %BuildDeploy.Component.Target{type: :docker, target: id}

      {report_status, report_desc} =
        case Job.Cache.copy_targets(config, id, checksum, [target], targets_dir) do
          :ok ->
            {Reporter.Status.ok(), targets_dir}

          {:error, reason} ->
            {Reporter.Status.error(reason, nil), nil}
        end

      end_time = Reporter.time()
      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      :ok
    end
  end

  def fun(
        %Config.Data{} = config,
        %BuildDeploy.Component{id: id, type: %BuildDeploy.Component.Deploy{build_target_dependencies: deploy_targets}},
        release_dir,
        build_checksums
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      build_checksum = Map.fetch!(build_checksums, id)
      targets_dir = Path.join(release_dir, id)

      {report_status, report_desc} =
        case Job.Cache.copy_targets(config, id, build_checksum, deploy_targets, targets_dir) do
          :ok ->
            {Reporter.Status.ok(), targets_dir}

          {:error, reason} ->
            {Reporter.Status.error(reason, nil), nil}
        end

      end_time = Reporter.time()
      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      Job.Common.stop_on_failure(report_status)

      :ok
    end
  end
end
