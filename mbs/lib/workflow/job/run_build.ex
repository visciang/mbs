defmodule MBS.Workflow.Job.RunBuild do
  @moduledoc """
  Workflow job logic for "build run" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Docker, Manifest, Utils}
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

      %Job.FunResult{checksum: checksum, targets: MapSet.new()}
    end
  end

  def fun(%Config.Data{}, %Manifest.Component{id: id, targets: targets} = component, force) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      checksum = Job.Utils.build_checksum(component, upstream_results)

      {report_status, report_desc} =
        with :cache_miss <- cache_get_targets(Const.cache_dir(), id, checksum, targets, force),
             :ok <- Toolchain.exec_build(component, checksum, upstream_results, job_id),
             :ok <- assert_targets(targets, checksum),
             :ok <- Job.Cache.put_targets(Const.cache_dir(), id, checksum, targets) do
          {Reporter.Status.ok(), checksum}
        else
          :cached ->
            {Reporter.Status.uptodate(), checksum}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil, nil}
        end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) or match?(Reporter.Status.uptodate(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{
        checksum: checksum,
        targets: transitive_targets(id, checksum, targets, upstream_results)
      }
    end
  end

  defp transitive_targets(id, checksum, targets, upstream_results) do
    {:ok, expanded_targets} = Job.Cache.expand_targets_path(Const.cache_dir(), id, checksum, targets)

    expanded_targets_set =
      expanded_targets
      |> Enum.map(&{id, &1})
      |> MapSet.new()

    expanded_upstream_targets_set =
      upstream_results
      |> Map.values()
      |> Enum.map(& &1.targets)
      |> Utils.union_mapsets()

    MapSet.union(expanded_targets_set, expanded_upstream_targets_set)
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
