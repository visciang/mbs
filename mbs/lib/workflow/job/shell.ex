defmodule MBS.Workflow.Job.Shell do
  @moduledoc """
  Workflow job logic for "shell" command
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Manifest}
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec fun(Reporter.t(), Config.Data.t(), Manifest.Type.t(), String.t()) :: Job.job_fun()
  def fun(_reporter, %Config.Data{}, %Manifest.Toolchain{checksum: checksum}, _shell_target) do
    fn _job_id, _upstream_results ->
      %Job.FunResult{checksum: checksum}
    end
  end

  def fun(
        _reporter,
        %Config.Data{} = config,
        %Manifest.Component{id: id, dir: component_dir, files: files} = component,
        shell_target
      ) do
    fn _job_id, upstream_results ->
      dependencies = Job.Utils.component_dependencies(component)
      upstream_results = Job.Utils.filter_upstream_results(upstream_results, dependencies)
      upstream_checksums_map = Job.Utils.upstream_results_to_checksums_map(upstream_results)
      checksum = Job.Utils.checksum(component_dir, files, upstream_checksums_map)

      if id == shell_target do
        Toolchain.shell_cmd(component, checksum, config, upstream_results)
        |> IO.puts()
      end

      %Job.FunResult{checksum: checksum}
    end
  end
end
