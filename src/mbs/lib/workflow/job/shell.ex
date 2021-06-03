defmodule MBS.Workflow.Job.Shell do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Config
  alias MBS.Manifest.BuildDeploy
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), BuildDeploy.Type.t(), String.t()) :: Job.fun()
  def fun(%Config.Data{}, %BuildDeploy.Toolchain{checksum: checksum}, _shell_target) do
    fn _job_id, _upstream_results ->
      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(%Config.Data{} = config, %BuildDeploy.Component{id: id} = component, shell_target) do
    fn _job_id, upstream_results ->
      checksum = Job.Utils.build_checksum(component, upstream_results)

      if id == shell_target do
        dependencies = Job.Utils.component_dependencies(component)
        upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)

        Toolchain.Shell.cmd(config, component, checksum, upstream_results)
        |> IO.puts()
      end

      %Job.FunResult{checksum: checksum}
    end
  end
end
