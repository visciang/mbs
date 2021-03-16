defmodule MBS.Workflow.Job do
  @moduledoc """
  Workflow job logic
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Manifest}
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  @type job_fun :: (String.t(), Dask.Job.upstream_results() -> Job.JobFunResult.t())

  @spec run_fun(Reporter.t(), Config.Data.t(), Manifest.Type.t()) :: job_fun()
  def run_fun(reporter, %Config.Data{}, %Manifest.Toolchain{id: id, checksum: checksum} = toolchain) do
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

      %Job.JobFunResult{checksum: checksum, targets: []}
    end
  end

  def run_fun(
        reporter,
        %Config.Data{cache: %{dir: cache_dir}} = config,
        %Manifest.Component{id: id, dir: component_dir, files: files, targets: targets} = component
      ) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      dependencies = Job.Utils.component_dependencies(component)
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)
      checksum = Job.Utils.checksum(component_dir, files, upstream_results)

      {report_status, report_desc} =
        with :cache_miss <- Job.Cache.get_targets(cache_dir, id, checksum, targets),
             :ok <- Toolchain.exec(component, checksum, config, upstream_results, job_id, reporter),
             :ok <- Job.Utils.assert_targets(targets, checksum),
             :ok <- Job.Cache.put_targets(cache_dir, id, checksum, targets) do
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

  @spec run_fun_on_exit(String.t(), Dask.Job.job_exec_result(), non_neg_integer(), Reporter.t()) :: :ok
  def run_fun_on_exit(job_id, job_exec_result, elapsed_time_ms, reporter) do
    case job_exec_result do
      :job_timeout ->
        Reporter.job_report(reporter, job_id, Reporter.Status.timeout(), "", elapsed_time_ms * 1_000)

      _ ->
        :ok
    end
  end

  @spec release_fun(Reporter.t(), Config.Data.t(), Manifest.Type.t(), Path.t()) :: job_fun()
  def release_fun(
        reporter,
        %Config.Data{cache: %{dir: cache_dir}},
        %Manifest.Toolchain{id: id, checksum: checksum},
        release_dir
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      targets_dir = Path.join(release_dir, id)
      target = %Manifest.Target{type: :docker, target: id}

      {report_status, report_desc} =
        case Job.Cache.copy_targets(cache_dir, id, checksum, [target], targets_dir, reporter) do
          :ok ->
            {Reporter.Status.ok(), targets_dir}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      if report_status == :ok do
        release_targets_manifest(id, checksum, [target], targets_dir)
      end

      end_time = Reporter.time()

      Reporter.job_report(reporter, job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.JobFunResult{checksum: checksum, targets: []}
    end
  end

  def release_fun(
        reporter,
        %Config.Data{cache: %{dir: cache_dir}},
        %Manifest.Component{id: id, dir: component_dir, files: files, targets: targets} = component,
        release_dir
      ) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      dependencies = Job.Utils.component_dependencies(component)
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)
      checksum = Job.Utils.checksum(component_dir, files, upstream_results)

      targets_dir = Path.join(release_dir, id)

      {report_status, report_desc} =
        case Job.Cache.copy_targets(cache_dir, id, checksum, targets, targets_dir, reporter) do
          :ok ->
            {Reporter.Status.ok(), targets_dir}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      if report_status == :ok do
        release_targets_manifest(id, checksum, targets, targets_dir)
      end

      end_time = Reporter.time()

      Reporter.job_report(reporter, job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.JobFunResult{checksum: checksum, targets: targets}
    end
  end

  @spec shell_fun(Reporter.t(), Config.Data.t(), Manifest.Type.t(), String.t()) :: job_fun()
  def shell_fun(_reporter, %Config.Data{}, %Manifest.Toolchain{checksum: checksum}, _shell_target) do
    fn _job_id, _upstream_results ->
      %Job.JobFunResult{checksum: checksum, targets: []}
    end
  end

  def shell_fun(
        _reporter,
        %Config.Data{} = config,
        %Manifest.Component{id: id, dir: component_dir, files: files, targets: targets} = component,
        shell_target
      ) do
    fn _job_id, upstream_results ->
      dependencies = Job.Utils.component_dependencies(component)
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)
      checksum = Job.Utils.checksum(component_dir, files, upstream_results)

      if id == shell_target do
        Toolchain.shell_cmd(component, checksum, config, upstream_results)
        |> IO.puts()
      end

      %Job.JobFunResult{checksum: checksum, targets: targets}
    end
  end

  @spec outdated_fun(Reporter.t(), Config.Data.t(), Manifest.Type.t()) :: job_fun()
  def outdated_fun(reporter, %Config.Data{} = _config, %Manifest.Toolchain{id: id, checksum: checksum}) do
    fn job_id, _upstream_results ->
      unless Job.Cache.hit_toolchain(id, checksum) do
        Reporter.job_report(reporter, job_id, Reporter.Status.outdated(), checksum, nil)
      end

      %Job.JobFunResult{checksum: checksum, targets: []}
    end
  end

  def outdated_fun(
        reporter,
        %Config.Data{} = config,
        %Manifest.Component{id: id, dir: component_dir, files: files, targets: targets} = component
      ) do
    fn job_id, upstream_results ->
      dependencies = Job.Utils.component_dependencies(component)
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)
      checksum = Job.Utils.checksum(component_dir, files, upstream_results)

      unless Job.Cache.hit_targets(config.cache.dir, id, checksum, targets) do
        Reporter.job_report(reporter, job_id, Reporter.Status.outdated(), checksum, nil)
      end

      %Job.JobFunResult{checksum: checksum, targets: targets}
    end
  end

  defp release_targets_manifest(id, checksum, targets, output_dir) do
    release_manifest_path = Path.join(output_dir, "manifest.json")

    release_manifest = %{
      id: id,
      checksum: checksum,
      targets:
        targets
        |> Enum.map(fn
          %Manifest.Target{type: :file} = target ->
            put_in(target.target, Path.basename(target.target))

          target ->
            target
        end)
        |> Enum.map(&Map.from_struct/1)
    }

    File.write!(release_manifest_path, Jason.encode!(release_manifest, pretty: true))
  end
end
