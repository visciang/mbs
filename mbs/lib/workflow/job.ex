defmodule MBS.Workflow.Job.JobFunResult do
  @moduledoc """
  Job function result data
  """

  defstruct [:checksum, :targets]
end

defmodule MBS.Workflow.Job do
  @moduledoc """
  Workflow job logic
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Manifest}
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  def job_fun(reporter, %Config.Data{}, %Manifest.Toolchain{id: id, checksum: checksum} = toolchain, logs_enabled) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      {report_status, report_desc} =
        with :cache_miss <- Job.Cache.get_toolchain(id, checksum),
             :ok <- Toolchain.build(toolchain, reporter, logs_enabled),
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

      %Job.JobFunResult{checksum: checksum, targets: []}
    end
  end

  def job_fun(
        reporter,
        %Config.Data{} = config,
        %Manifest.Component{
          id: id,
          files: files,
          dependencies: dependencies,
          targets: targets,
          toolchain: toolchain
        } = component,
        logs_enabled
      ) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      upstream_results = Job.Utils.filter_upstream_results(upstream_results, [toolchain.id | dependencies])
      checksum = Job.Utils.checksum(files, upstream_results)

      {report_status, report_desc} =
        with :cache_miss <- Job.Cache.get_targets(config.cache.directory, id, checksum, targets),
             :ok <- Toolchain.exec(component, config.cache.directory, upstream_results, job_id, reporter, logs_enabled),
             :ok <- Job.Utils.assert_targets(targets),
             :ok <- Job.Cache.put_targets(config.cache.directory, id, checksum, targets) do
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

      %Job.JobFunResult{checksum: checksum, targets: targets}
    end
  end

  def job_fun_on_exit(job_id, job_exec_result, elapsed_time_ms, reporter) do
    case job_exec_result do
      :job_timeout ->
        Reporter.job_report(reporter, job_id, Reporter.Status.timeout(), "", elapsed_time_ms * 1_000)

      _ ->
        :ok
    end
  end

  def outdated_fun(reporter, %Config.Data{} = _config, %Manifest.Toolchain{id: id, checksum: checksum}) do
    fn job_id, _upstream_results ->
      unless Job.Cache.hit_toolchain(id, checksum) do
        Reporter.job_report(reporter, job_id, Reporter.Status.outdated(), checksum, nil)
      end

      %Job.JobFunResult{checksum: checksum, targets: []}
    end
  end

  def outdated_fun(reporter, %Config.Data{} = config, %Manifest.Component{
        id: id,
        toolchain: toolchain,
        files: files,
        dependencies: dependencies,
        targets: targets
      }) do
    fn job_id, upstream_results ->
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, [toolchain.id | dependencies])
      checksum = Job.Utils.checksum(files, upstream_results)

      unless Job.Cache.hit_targets(config.cache.directory, id, checksum, targets) do
        Reporter.job_report(reporter, job_id, Reporter.Status.outdated(), checksum, nil)
      end

      %Job.JobFunResult{checksum: checksum, targets: targets}
    end
  end
end
