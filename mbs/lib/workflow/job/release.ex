defmodule MBS.Workflow.Job.Release do
  @moduledoc """
  Workflow job logic for "release" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Manifest}
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), Manifest.Type.t(), Path.t(), %{String.t() => String.t()}) :: Job.job_fun()
  def fun(
        %Config.Data{},
        %Manifest.Toolchain{type: :deploy, dir: toolchain_dir, id: id, checksum: checksum},
        release_dir,
        _build_checksums
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      targets_dir = Path.join(release_dir, id)
      target = %Manifest.Target{type: :docker, target: id}

      {report_status, report_desc} =
        case Job.Cache.copy_targets(Const.cache_dir(), id, checksum, [target], targets_dir) do
          :ok ->
            {Reporter.Status.ok(), targets_dir}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      if report_status == :ok do
        release_copy_mbs_toolchain_manifest(toolchain_dir, targets_dir)
        release_targets_metadata(id, checksum, targets_dir)
      end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(
        %Config.Data{},
        %Manifest.Component{type: :deploy, id: id, dir: component_dir, files: deploy_targets} = component,
        release_dir,
        build_checksums
      ) do
    fn job_id, upstream_results ->
      start_time = Reporter.time()

      build_checksum = Map.fetch!(build_checksums, id)

      dependencies = Job.Utils.component_dependencies(component)
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)

      deploy_upstream_checksums_map = Job.Utils.upstream_results_to_checksums_map(upstream_results)
      deploy_upstream_deps_checksum = Job.Utils.checksum(component_dir, [], deploy_upstream_checksums_map)
      deploy_checksum = "#{build_checksum}-#{deploy_upstream_deps_checksum}"

      targets_dir = Path.join(release_dir, id)

      {report_status, report_desc} =
        case Job.Cache.copy_targets(Const.cache_dir(), id, build_checksum, deploy_targets, targets_dir) do
          :ok ->
            {Reporter.Status.ok(), targets_dir}

          {:error, reason} ->
            {Reporter.Status.error(reason), nil}
        end

      if report_status == :ok do
        release_copy_mbs_deploy_manifest(component_dir, targets_dir)
        release_targets_metadata(id, build_checksum, targets_dir)
      end

      end_time = Reporter.time()

      Reporter.job_report(job_id, report_status, report_desc, end_time - start_time)

      unless match?(Reporter.Status.ok(), report_status) do
        raise "Job failed #{inspect(report_status)}"
      end

      %Job.FunResult{checksum: deploy_checksum}
    end
  end

  defp release_targets_metadata(id, checksum, output_dir) do
    release_metadata_path = Path.join(output_dir, Const.release_metadata())

    release_metadata = %{
      id: id,
      checksum: checksum
    }

    File.write!(release_metadata_path, Jason.encode!(release_metadata, pretty: true))
  end

  defp release_copy_mbs_toolchain_manifest(src_dir, output_dir) do
    File.cp!(
      Path.join(src_dir, Const.manifest_toolchain_filename()),
      Path.join(output_dir, Const.manifest_toolchain_filename())
    )
  end

  defp release_copy_mbs_deploy_manifest(src_dir, output_dir) do
    File.cp!(
      Path.join(src_dir, Const.manifest_deploy_filename()),
      Path.join(output_dir, Const.manifest_deploy_filename())
    )
  end
end