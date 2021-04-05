defmodule MBS.Workflow.Job.Release do
  @moduledoc """
  Workflow job logic for "release" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Manifest}
  alias MBS.Workflow.Job

  require Reporter.Status

  @type fun :: (String.t(), Dask.Job.upstream_results() -> :ok)

  @spec fun(Config.Data.t(), Manifest.Type.t(), Path.t(), %{String.t() => String.t()}) :: fun()
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
        case Job.Cache.copy_targets(id, checksum, [target], targets_dir) do
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

      :ok
    end
  end

  def fun(
        %Config.Data{},
        %Manifest.Component{type: :deploy, id: id, dir: component_dir, files: deploy_targets},
        release_dir,
        build_checksums
      ) do
    fn job_id, _upstream_results ->
      start_time = Reporter.time()

      build_checksum = Map.fetch!(build_checksums, id)
      targets_dir = Path.join(release_dir, id)

      {report_status, report_desc} =
        case Job.Cache.copy_targets(id, build_checksum, deploy_targets, targets_dir) do
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

      :ok
    end
  end

  @spec release_targets_metadata(String.t(), String.t(), Path.t()) :: :ok
  defp release_targets_metadata(id, checksum, output_dir) do
    release_metadata_path = Path.join(output_dir, Const.release_metadata_filename())

    release_metadata = %{
      id: id,
      checksum: checksum
    }

    File.write!(release_metadata_path, Jason.encode!(release_metadata, pretty: true))
  end

  @spec release_copy_mbs_toolchain_manifest(Path.t(), Path.t()) :: :ok
  defp release_copy_mbs_toolchain_manifest(src_dir, output_dir) do
    File.cp!(
      Path.join(src_dir, Const.manifest_toolchain_filename()),
      Path.join(output_dir, Const.manifest_toolchain_filename())
    )
  end

  @spec release_copy_mbs_deploy_manifest(Path.t(), Path.t()) :: :ok
  defp release_copy_mbs_deploy_manifest(src_dir, output_dir) do
    File.cp!(
      Path.join(src_dir, Const.manifest_deploy_filename()),
      Path.join(output_dir, Const.manifest_deploy_filename())
    )
  end
end
