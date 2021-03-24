defmodule MBS.Workflow.Job.RunBuild do
  @moduledoc """
  Workflow job logic for "build run" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Manifest}
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Reporter.t(), Config.Data.t(), Manifest.Type.t()) :: Job.job_fun()
  def fun(reporter, %Config.Data{}, %Manifest.Toolchain{id: id, checksum: checksum} = toolchain) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      {report_status, report_desc} =
        with :cache_miss <- Job.Cache.get_toolchain(id, checksum),
             :ok <- Toolchain.build(toolchain, reporter),
             :ok <- Job.Cache.put_toolchain(id, checksum) do
          {Reporter.Status.ok(), checksum}
        else
          :cached ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(reporter, job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(
        reporter,
        %Config.Data{} = config,
        %Manifest.Component{id: id, dir: component_dir, files: files, targets: targets} = component
      ) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      dependencies = Job.Utils.component_dependencies(component)
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)
      upstream_checksums_map = Job.Utils.upstream_results_to_checksums_map(upstream_results)
      checksum = Job.Utils.checksum(component_dir, files, upstream_checksums_map)

      {report_status, report_desc} =
        with :cache_miss <- Job.Cache.get_targets(Const.cache_dir(), id, checksum, targets),
             :ok <- Toolchain.exec_build(component, checksum, config, upstream_results, job_id, reporter),
             :ok <- Job.Utils.assert_targets(targets, checksum),
             :ok <- Job.Cache.put_targets(Const.cache_dir(), id, checksum, targets) do
          {Reporter.Status.ok(), checksum}
        else
          :cached ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(reporter, job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: checksum}
    end
  end
end
