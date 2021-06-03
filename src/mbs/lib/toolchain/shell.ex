defmodule MBS.Toolchain.Shell do
  @moduledoc false

  alias MBS.{Config, Docker, DockerCompose}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Toolchain
  alias MBS.Workflow.Job

  @spec cmd(Config.Data.t(), BuildDeploy.Component.t(), String.t(), Job.upstream_results()) :: String.t()
  def cmd(
        %Config.Data{} = config,
        %BuildDeploy.Component{id: id, toolchain: toolchain, services: services_compose_file} = component,
        checksum,
        upstream_results
      ) do
    env = Toolchain.RunBuild.env_vars(config, component, checksum, upstream_results)
    job_id = "#{id}_shell"

    {docker_network_name, cmd_up, cmd_down} =
      if services_compose_file != nil do
        {:ok, docker_network_name, cmd_up} = DockerCompose.compose_cmd(:up, services_compose_file, env, job_id)
        {:ok, _docker_network_name, cmd_down} = DockerCompose.compose_cmd(:down, services_compose_file, env, job_id)
        {docker_network_name, cmd_up, cmd_down}
      else
        {nil, "true", "true"}
      end

    opts = Toolchain.RunBuild.run_opts(component, docker_network_name, true) ++ ["-i", "--entrypoint", "sh"]
    cmd_run = Docker.container_run_cmd(toolchain.id, toolchain.checksum, opts, env)

    "#{cmd_up}; #{cmd_run}; #{cmd_down}"
  end
end
