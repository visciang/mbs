defmodule MBS.Workflow.Job.Outdated do
  @moduledoc """
  Workflow job logic for "outdated" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Const, Manifest}
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), Manifest.Type.t()) :: Job.job_fun()
  def fun(%Config.Data{}, %Manifest.Toolchain{id: id, checksum: checksum}) do
    fn job_id, _upstream_results ->
      unless Job.Cache.hit_toolchain(id, checksum) do
        Reporter.job_report(job_id, Reporter.Status.outdated(), checksum, nil)
      end

      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(%Config.Data{}, %Manifest.Component{id: id, dir: component_dir, files: files, targets: targets} = component) do
    fn job_id, upstream_results ->
      dependencies = Job.Utils.component_dependencies(component)
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)
      upstream_checksums_map = Job.Utils.upstream_results_to_checksums_map(upstream_results)
      checksum = Job.Utils.checksum(component_dir, files, upstream_checksums_map)

      unless Job.Cache.hit_targets(Const.cache_dir(), id, checksum, targets) do
        Reporter.job_report(job_id, Reporter.Status.outdated(), checksum, nil)
      end

      %Job.FunResult{checksum: checksum}
    end
  end
end
