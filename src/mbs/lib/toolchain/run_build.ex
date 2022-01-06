defmodule MBS.Toolchain.RunBuild do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Docker, DockerCompose}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Toolchain
  alias MBS.Workflow.Job.RunBuild.Context.Deps

  require Reporter.Status

  @type opts :: [String.t()]
  @type env_list :: [{String.t(), String.t()}]

  @sh_sleep_forever_cmd ["-c", "while true; do sleep 2; done"]

  @spec up(Config.Data.t(), BuildDeploy.Component.t(), boolean()) :: {:ok, env_list()} | {:error, term()}
  def up(
        %Config.Data{} = config,
        %BuildDeploy.Component{id: id, toolchain: toolchain} = component,
        mount_compoment_dir
      ) do
    envs = env_vars(config, component)

    with {:ok, docker_network_name} <- exec_services(:up, component, envs),
         run_opts_ = run_opts(:run, component, docker_network_name, mount_compoment_dir),
         run_opts_ = run_opts_ ++ ["--detach", "--name", id, "--entrypoint", "sh"],
         :ok <- Docker.container_run(toolchain.id, toolchain.checksum, run_opts_, envs, @sh_sleep_forever_cmd, id) do
      {:ok, envs}
    else
      error ->
        error
    end
  end

  @spec down(BuildDeploy.Component.t()) :: :ok | {:error, {term(), pos_integer()}}
  def down(%BuildDeploy.Component{id: id} = component) do
    exec_services(:down, component, [])
    Docker.container_stop(id, id)
  end

  @spec exec(BuildDeploy.Component.t(), Deps.changed_deps(), env_list()) :: :ok | {:error, String.t()}
  def exec(%BuildDeploy.Component{} = component, changed_deps, envs) do
    deps_change_steps =
      if changed_deps != [] and component.toolchain.deps_change_step != nil do
        [component.toolchain.deps_change_step]
      else
        []
      end

    Toolchain.Common.exec(component, envs, deps_change_steps ++ component.toolchain.steps)
  end

  @spec exec_services(DockerCompose.compose_action(), BuildDeploy.Component.t(), env_list()) ::
          {:ok, nil | String.t()} | {:error, term()}
  defp exec_services(
         action,
         %BuildDeploy.Component{id: id, type: %BuildDeploy.Component.Build{services: services_compose_file}},
         env
       ) do
    if services_compose_file == nil do
      {:ok, nil}
    else
      reporter_id = "#{id}:services"
      Reporter.job_report(reporter_id, Reporter.Status.log(), "Sidecar services #{action} ...", nil)
      DockerCompose.compose(action, services_compose_file, env, reporter_id)
    end
  end

  @spec run_opts(BuildDeploy.Component.docker_opts_type(), BuildDeploy.Component.t(), nil | String.t(), boolean()) ::
          opts()
  def run_opts(
        action,
        %BuildDeploy.Component{docker_opts: docker_opts, dir: component_dir, project_dir: project_dir},
        network_name,
        mount_compoment_dir
      ) do
    opts = ["--rm", "-t" | Map.get(docker_opts, action, [])]
    opts_work_dir = ["-w", "#{component_dir}"]
    opts_dir_mount = if mount_compoment_dir, do: ["-v", "#{project_dir}:#{project_dir}"], else: []
    opts_net = if network_name != nil, do: ["--net", network_name], else: []

    opts ++ opts_work_dir ++ opts_dir_mount ++ opts_net
  end

  @spec env_vars(Config.Data.t(), BuildDeploy.Component.t()) :: env_list()
  def env_vars(
        %Config.Data{project: project},
        %BuildDeploy.Component{id: id, dir: dir, checksum: checksum, dependencies: dependencies}
      ) do
    env =
      Enum.map(dependencies, fn %BuildDeploy.Component{id: dep_id, checksum: dep_checksum} ->
        shell_dep_id =
          dep_id
          |> String.upcase()
          |> String.replace([":", "-"], "_")

        {"MBS_CHECKSUM_#{shell_dep_id}", dep_checksum}
      end)

    [{"MBS_PROJECT_ID", project}, {"MBS_ID", id}, {"MBS_CWD", dir}, {"MBS_CHECKSUM", checksum} | env]
  end
end
