defmodule MBS.Workflow.Job.RunBuild do
  @moduledoc """
  Workflow job logic for "build run" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Docker, Manifest}
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), Manifest.Type.t(), boolean()) :: Job.job_fun()
  def fun(%Config.Data{}, %Manifest.Toolchain{id: id, checksum: checksum} = toolchain, force) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      {report_status, report_desc} =
        with :cache_miss <- cache_get_toolchain(id, checksum, force),
             :ok <- Toolchain.build(toolchain),
             :ok <- Job.Cache.put_toolchain(id, checksum) do
          {Reporter.Status.ok(), checksum}
        else
          :cached ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(%Config.Data{} = config, %Manifest.Component{id: id, targets: targets} = component, force) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      checksum = Job.Utils.build_checksum(component, upstream_results)

      {report_status, report_desc} =
        with :cache_miss <- cache_get_targets(Const.cache_dir(), id, checksum, targets, force),
             :ok <- Toolchain.exec_build(component, checksum, config, upstream_results, job_id),
             :ok <- assert_targets(targets, checksum),
             :ok <- Job.Cache.put_targets(Const.cache_dir(), id, checksum, targets) do
          {Reporter.Status.ok(), checksum}
        else
          :cached ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: checksum}
    end
  end

  defp cache_get_toolchain(id, checksum, force) do
    if force do
      :cache_miss
    else
      Job.Cache.get_toolchain(id, checksum)
    end
  end

  defp cache_get_targets(cache_dir, id, checksum, targets, force) do
    if force do
      :cache_miss
    else
      Job.Cache.get_targets(cache_dir, id, checksum, targets)
    end
  end

  defp assert_targets([], _checksum), do: :ok

  defp assert_targets(targets, checksum) do
    missing_targets =
      Enum.filter(targets, fn
        %Manifest.Target{type: :file, target: target} ->
          not File.exists?(target)

        %Manifest.Target{type: :docker, target: target} ->
          not Docker.image_exists(target, checksum)
      end)

    if length(missing_targets) != 0 do
      {:error, "Missing targets #{inspect(missing_targets)}"}
    else
      :ok
    end
  end
end
