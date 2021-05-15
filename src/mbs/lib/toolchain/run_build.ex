defmodule MBS.Toolchain.RunBuild do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Const, Docker, DockerCompose}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Toolchain
  alias MBS.Workflow.Job
  alias MBS.Workflow.Job.RunBuild.Context.Deps

  require Reporter.Status

  @type opts :: [String.t()]
  @type env_list :: [{String.t(), String.t()}]

  @sh_sleep_forever_cmd ["-c", "while true; do sleep 2; done"]

  @spec up(BuildDeploy.Component.t(), String.t(), Job.upstream_results(), boolean()) ::
          {:ok, env_list()} | {:error, term()}
  def up(
        %BuildDeploy.Component{id: id, toolchain: toolchain} = component,
        checksum,
        upstream_results,
        mount_compoment_dir
      ) do
    envs = env_vars(component, checksum, upstream_results)

    with {:ok, docker_network_name} <- exec_services(:up, component, envs),
         run_opts_ = run_opts(component, docker_network_name, mount_compoment_dir),
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
  defp exec_services(action, %BuildDeploy.Component{id: id, services: services_compose_file}, env) do
    if services_compose_file == nil do
      {:ok, nil}
    else
      reporter_id = "#{id}:services"
      Reporter.job_report(reporter_id, Reporter.Status.log(), "Sidecar services #{action} ...", nil)
      DockerCompose.compose(action, services_compose_file, env, reporter_id)
    end
  end

  @spec run_opts(BuildDeploy.Component.t(), nil | String.t(), boolean()) :: opts()
  def run_opts(
        %BuildDeploy.Component{docker_opts: docker_opts, dir: component_dir, project_dir: project_dir},
        network_name,
        mount_compoment_dir
      ) do
    opts = ["--rm", "-t" | docker_opts]
    opts_work_dir = ["-w", "#{component_dir}"]
    opts_dir_mount = if mount_compoment_dir, do: ["-v", "#{project_dir}:#{project_dir}"], else: []
    opts_net = if network_name != nil, do: ["--net", network_name], else: []

    opts ++ opts_work_dir ++ opts_dir_mount ++ opts_net
  end

  @spec env_vars(BuildDeploy.Component.t(), String.t(), Job.upstream_results()) :: env_list()
  def env_vars(
        %BuildDeploy.Component{id: id, dir: dir, dependencies: dependencies},
        checksum,
        upstream_results
      ) do
    env =
      Enum.map(dependencies, fn dep_id ->
        %Job.FunResult{checksum: dep_checksum} = Map.fetch!(upstream_results, dep_id)

        shell_dep_id =
          dep_id
          |> String.upcase()
          |> String.replace([":", "-"], "_")

        {"MBS_CHECKSUM_#{shell_dep_id}", dep_checksum}
      end)

    [{"MBS_PROJECT_ID", Const.project_id()}, {"MBS_ID", id}, {"MBS_CWD", dir}, {"MBS_CHECKSUM", checksum} | env]
  end
end
