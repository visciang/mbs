defmodule MBS.Toolchain do
  @moduledoc """
  Toolchain functions
  """

  alias MBS.CLI.Reporter
  alias MBS.{Const, Docker, DockerCompose}
  alias MBS.Manifest.{BuildDeploy, Dependency}
  alias MBS.Workflow.Job

  require Reporter.Status

  @type opts :: [String.t()]
  @type env_list :: [{String.t(), String.t()}]

  @spec build(BuildDeploy.Toolchain.t()) :: :ok | {:error, term()}
  def build(%BuildDeploy.Toolchain{
        id: id,
        dir: dir,
        checksum: checksum,
        dockerfile: dockerfile,
        docker_opts: docker_opts
      }) do
    Docker.image_build(docker_opts, id, checksum, dir, dockerfile, "#{id}:build")
  end

  @spec shell_cmd(BuildDeploy.Component.t(), String.t(), Job.upstream_results()) :: String.t()
  def shell_cmd(
        %BuildDeploy.Component{id: id, toolchain: toolchain, services: services_compose_file} = component,
        checksum,
        upstream_results
      ) do
    env = run_build_env_vars(component, checksum, upstream_results)
    job_id = "#{id}_shell"

    {docker_network_name, cmd_up, cmd_down} =
      if services_compose_file != nil do
        {:ok, docker_network_name, cmd_up} = DockerCompose.compose_cmd(:up, services_compose_file, env, job_id)
        {:ok, _docker_network_name, cmd_down} = DockerCompose.compose_cmd(:down, services_compose_file, env, job_id)
        {docker_network_name, cmd_up, cmd_down}
      else
        {nil, "true", "true"}
      end

    opts = run_opts(component, docker_network_name, false) ++ ["--entrypoint", "sh", "--interactive"]
    cmd_run = Docker.image_run_cmd(toolchain.id, toolchain.checksum, opts, env)

    "#{cmd_up}; #{cmd_run}; #{cmd_down}"
  end

  @spec exec_build(
          BuildDeploy.Component.t(),
          String.t(),
          Job.upstream_results(),
          [{Path.t(), Dependency.Type.t()}],
          boolean()
        ) ::
          :ok | {:error, String.t()}
  def exec_build(%BuildDeploy.Component{} = component, checksum, upstream_results, changed_deps, sandboxed) do
    env = run_build_env_vars(component, checksum, upstream_results)

    deps_change_steps =
      if changed_deps != [] and component.toolchain.deps_change_step != nil do
        [component.toolchain.deps_change_step]
      else
        []
      end

    res =
      with {:ok, docker_network_name} <- exec_services(:up, component, env),
           run_opts = run_opts(component, docker_network_name, sandboxed),
           :ok <- exec(component, env, deps_change_steps, run_opts),
           :ok <- exec(component, env, component.toolchain.steps, run_opts) do
        Enum.each(changed_deps, fn {path, type} ->
          Dependency.write(path, type)
        end)
      else
        error -> error
      end

    res
  end

  @spec exec_services(DockerCompose.compose_action(), BuildDeploy.Component.t(), env_list()) ::
          {:ok, nil | String.t()} | {:error, term()}
  def exec_services(_action, %BuildDeploy.Component{services: nil}, _env),
    do: {:ok, nil}

  def exec_services(action, %BuildDeploy.Component{id: id, services: services_compose_file}, env) do
    reporter_id = "#{id}:services"
    Reporter.job_report(reporter_id, Reporter.Status.log(), "Sidecar services #{action} ...", nil)

    DockerCompose.compose(action, services_compose_file, env, reporter_id)
  end

  @spec exec_deploy(BuildDeploy.Component.t(), String.t()) :: :ok | {:error, String.t()}
  def exec_deploy(%BuildDeploy.Component{} = component, checksum) do
    env = run_deploy_env_vars(component, checksum)
    run_opts = run_deploy_opts(component)
    exec(component, env, component.toolchain.steps, run_opts)
  end

  @spec exec_destroy(BuildDeploy.Component.t(), String.t()) :: :ok | {:error, String.t()}
  def exec_destroy(%BuildDeploy.Component{} = component, checksum) do
    env = run_deploy_env_vars(component, checksum)
    component = put_in(component.toolchain.steps, ["destroy"])
    run_opts = run_deploy_opts(component)
    exec(component, env, component.toolchain.destroy_steps, run_opts)
  end

  @spec exec(BuildDeploy.Component.t(), env_list(), [String.t()], opts()) :: :ok | {:error, String.t()}
  defp exec(
         %BuildDeploy.Component{id: id, toolchain: toolchain, toolchain_opts: toolchain_opts},
         env,
         toolchain_steps,
         run_opts
       ) do
    toolchain_opts = toolchain_opts_env_subs(toolchain_opts, env)

    Enum.reduce_while(toolchain_steps, :ok, fn toolchain_step, _ ->
      reporter_id = "#{id}:#{toolchain_step}"
      start_time = Reporter.time()

      case Docker.image_run(
             toolchain.id,
             toolchain.checksum,
             run_opts,
             env,
             [toolchain_step | toolchain_opts],
             reporter_id
           ) do
        :ok ->
          Reporter.job_report(reporter_id, Reporter.Status.ok(), nil, Reporter.time() - start_time)
          {:cont, :ok}

        {:error, {cmd_result, cmd_exit_status}} ->
          Reporter.job_report(reporter_id, Reporter.Status.error(""), nil, Reporter.time() - start_time)
          {:halt, {:error, "exec error: exit status #{inspect(cmd_exit_status)}\n\n#{inspect(cmd_result)}"}}
      end
    end)
  end

  @spec run_opts(BuildDeploy.Component.t(), nil | String.t(), boolean()) :: opts()
  defp run_opts(%BuildDeploy.Component{docker_opts: docker_opts, dir: component_dir}, network_name, sandboxed) do
    opts = ["--rm", "-t" | docker_opts]
    opts_work_dir = ["-w", "#{component_dir}"]

    opts_dir_mount =
      if sandboxed do
        ["-v", "#{Const.tmp_volume()}:#{Const.tmp_dir()}"]
      else
        ["-v", "#{component_dir}:#{component_dir}"]
      end

    net_opts = if network_name != nil, do: ["--net", network_name], else: []

    opts ++ opts_work_dir ++ opts_dir_mount ++ net_opts
  end

  @spec run_deploy_opts(BuildDeploy.Component.t()) :: opts()
  def run_deploy_opts(%BuildDeploy.Component{docker_opts: docker_opts, dir: work_dir}) do
    opts = ["--rm", "-t" | docker_opts]
    opts_work_dir = ["-w", "#{work_dir}"]

    # NOTE:
    # mbs container will run the toolchain in "docker-in-docker".
    # A Docker container in a Docker container uses the parent HOST's Docker daemon and hence,
    # any volumes that are mounted in the  "docker-in-docker" case is still referenced from the HOST,
    # and not from the Container.
    # That's why we mount the original host docker volume.
    opts_dir_mount = ["-v", "#{Const.release_volume()}:#{Const.releases_dir()}"]

    opts ++ opts_work_dir ++ opts_dir_mount
  end

  @spec run_build_env_vars(BuildDeploy.Component.t(), String.t(), Job.upstream_results()) :: env_list()
  defp run_build_env_vars(
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
          |> String.replace(":", "_")
          |> String.replace("-", "_")

        {"MBS_CHECKSUM_#{shell_dep_id}", dep_checksum}
      end)

    [{"MBS_ID", id}, {"MBS_CWD", dir}, {"MBS_CHECKSUM", checksum} | env]
  end

  @spec run_deploy_env_vars(BuildDeploy.Component.t(), String.t()) :: env_list()
  defp run_deploy_env_vars(%BuildDeploy.Component{id: id, dir: dir}, checksum) do
    [{"MBS_ID", id}, {"MBS_CWD", dir}, {"MBS_CHECKSUM", checksum}]
  end

  @spec toolchain_opts_env_subs([String.t()], env_list()) :: [String.t()]
  defp toolchain_opts_env_subs(toolchain_opts, env) do
    Enum.map(toolchain_opts, fn toolchain_opt ->
      Enum.reduce(env, toolchain_opt, fn {env_name, env_value}, toolchain_opt ->
        String.replace(toolchain_opt, "${#{env_name}}", env_value)
      end)
    end)
  end
end
