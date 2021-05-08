defmodule MBS.Workflow.Job.Outdated do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Config
  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t()) :: Job.fun()
  def fun(%Config.Data{}, %BuildDeploy.Toolchain{id: id, checksum: checksum}) do
    fn job_id, _upstream_results ->
      unless Job.Cache.hit_toolchain(id, checksum) do
        Reporter.job_report(job_id, Reporter.Status.outdated(), checksum, nil)
      end

      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(%Config.Data{}, %BuildDeploy.Component{id: id, targets: targets} = component) do
    fn job_id, upstream_results ->
      checksum = Job.Utils.build_checksum(component, upstream_results)

      unless Job.Cache.hit_targets(id, checksum, targets) do
        Reporter.job_report(job_id, Reporter.Status.outdated(), checksum, nil)
      end

      %Job.FunResult{checksum: checksum}
    end
  end
end
