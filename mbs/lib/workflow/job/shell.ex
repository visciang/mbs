defmodule MBS.Workflow.Job.Shell do
  @moduledoc """
  Workflow job logic for "shell" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Manifest}
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Config.Data.t(), Manifest.Type.t(), String.t()) :: Job.job_fun()
  def fun(%Config.Data{}, %Manifest.Toolchain{checksum: checksum}, _shell_target) do
    fn _job_id, _upstream_results ->
      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(%Config.Data{}, %Manifest.Component{id: id} = component, shell_target) do
    fn _job_id, upstream_results ->
      checksum = Job.Utils.build_checksum(component, upstream_results)

      if id == shell_target do
        dependencies = Job.Utils.component_dependencies(component)
        upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)

        Toolchain.shell_cmd(component, checksum, upstream_results)
        |> IO.puts()
      end

      %Job.FunResult{checksum: checksum}
    end
  end
end
