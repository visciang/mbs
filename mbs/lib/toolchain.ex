defmodule MBS.Toolchain do
  @moduledoc """
  Toolchain functions
  """

  alias MBS.CLI.Reporter
  alias MBS.{Const, DependencyManifest, Docker, Manifest}
  alias MBS.Workflow.Job

  require Reporter.Status

  @type opts :: [String.t()]
  @type env_list :: [{String.t(), String.t()}]

  @spec build(Manifest.Toolchain.t()) :: :ok | {:error, term()}
  def build(%Manifest.Toolchain{id: id, dir: dir, checksum: checksum, dockerfile: dockerfile, docker_opts: docker_opts}) do
    Docker.image_build(docker_opts, id, checksum, dir, dockerfile, "#{id}:build")
  end

  @spec shell_cmd(Manifest.Component.t(), String.t(), Job.upstream_results()) :: String.t()
  def shell_cmd(
        %Manifest.Component{id: id, toolchain: toolchain, services: services_compose_file} = component,
        checksum,
        upstream_results
      ) do
    env = run_build_env_vars(component, checksum, upstream_results)
    job_id = "#{id}_shell"

    {docker_network_name, cmd_up, cmd_down} =
      if services_compose_file != nil do
        {:ok, docker_network_name, cmd_up} = Docker.compose_cmd(:up, services_compose_file, env, job_id)
        {:ok, _docker_network_name, cmd_down} = Docker.compose_cmd(:down, services_compose_file, env, job_id)
        {docker_network_name, cmd_up, cmd_down}
      else
        {nil, "true", "true"}
      end

    opts = run_opts(component, docker_network_name) ++ ["--entrypoint", "sh", "--interactive"]
    cmd_run = Docker.image_run_cmd(toolchain.id, toolchain.checksum, opts, env)

    "#{cmd_up}; #{cmd_run}; #{cmd_down}"
  end

  @spec exec_build(
          Manifest.Component.t(),
          String.t(),
          Job.upstream_results(),
          [{Path.t(), DependencyManifest.Type.t()}],
          String.t()
        ) :: :ok | {:error, String.t()}
  def exec_build(%Manifest.Component{} = component, checksum, upstream_results, changed_deps, job_id) do
    env = run_build_env_vars(component, checksum, upstream_results)

    deps_change_steps =
      if changed_deps != [] and component.toolchain.deps_change_step != nil do
        [component.toolchain.deps_change_step]
      else
        []
      end

    res =
      with {:ok, docker_network_name} <- exec_services(:up, component, env, job_id),
           run_opts = run_opts(component, docker_network_name),
           :ok <- exec(component, env, job_id, deps_change_steps, run_opts),
           :ok <- exec(component, env, job_id, component.toolchain.steps, run_opts) do
        Enum.each(changed_deps, fn {path, type} ->
          DependencyManifest.write(path, type)
        end)
      else
        error -> error
      end

    exec_services(:down, component, env, job_id)
    res
  end

  @spec exec_services(:up | :down, Manifest.Component.t(), env_list(), String.t()) ::
          {:ok, nil | String.t()} | {:error, term()}
  defp exec_services(_action, %Manifest.Component{services: nil}, _env, _job_id),
    do: {:ok, nil}

  defp exec_services(action, %Manifest.Component{services: services_compose_file}, env, job_id) do
    reporter_id = "#{job_id}:services"
    Reporter.job_report(reporter_id, Reporter.Status.log(), "Sidecar services #{action} ...", nil)

    Docker.compose(action, services_compose_file, env, reporter_id)
  end

  @spec exec_deploy(Manifest.Component.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def exec_deploy(%Manifest.Component{} = component, checksum, job_id) do
    env = run_deploy_env_vars(component, checksum)
    run_opts = run_deploy_opts(component)
    exec(component, env, job_id, component.toolchain.steps, run_opts)
  end

  @spec exec_destroy(Manifest.Component.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def exec_destroy(%Manifest.Component{} = component, checksum, job_id) do
    env = run_deploy_env_vars(component, checksum)
    component = put_in(component.toolchain.steps, ["destroy"])
    run_opts = run_deploy_opts(component)
    exec(component, env, job_id, component.toolchain.destroy_steps, run_opts)
  end

  @spec exec(Manifest.Component.t(), env_list(), String.t(), [String.t()], opts()) :: :ok | {:error, String.t()}
  defp exec(
         %Manifest.Component{toolchain: toolchain, toolchain_opts: toolchain_opts},
         env,
         job_id,
         toolchain_steps,
         run_opts
       ) do
    toolchain_opts = toolchain_opts_env_subs(toolchain_opts, env)

    Enum.reduce_while(toolchain_steps, :ok, fn toolchain_step, _ ->
      reporter_id = "#{job_id}:#{toolchain_step}"
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

  @spec run_opts(Manifest.Component.t(), nil | String.t()) :: opts()
  defp run_opts(%Manifest.Component{docker_opts: docker_opts, dir: work_dir}, network_name) do
    opts = ["--rm", "-t" | docker_opts]
    work_dir_opts = ["-w", "#{work_dir}"]
    dir_mount_opts = ["-v", "#{work_dir}:#{work_dir}"]
    net_opts = if network_name != nil, do: ["--net", network_name], else: []

    opts ++ work_dir_opts ++ dir_mount_opts ++ net_opts
  end

  @spec run_deploy_opts(Manifest.Component.t()) :: opts()
  def run_deploy_opts(%Manifest.Component{docker_opts: docker_opts, dir: work_dir}) do
    opts = ["--rm", "-t" | docker_opts]
    work_dir_opts = ["-w", "#{work_dir}"]

    # NOTE: mbs container will run the toolchain in "docker-in-docker"
    # A Docker container in a Docker container uses the parent HOST's
    # Docker daemon and hence,  any volumes that are mounted in the
    # "docker-in-docker" case is still referenced from the HOST, and
    # not from the Container.
    # That's why we mount the original host docker volume via the
    # evnironment variable MBS_RELEASE_VOLUME
    mbs_release_volume = System.fetch_env!("MBS_RELEASE_VOLUME")
    dir_mount_opts = ["-v", "#{mbs_release_volume}:#{Const.releases_dir()}"]

    opts ++ work_dir_opts ++ dir_mount_opts
  end

  @spec run_build_env_vars(Manifest.Component.t(), String.t(), Job.upstream_results()) :: env_list()
  defp run_build_env_vars(
         %Manifest.Component{id: id, dir: dir, dependencies: dependencies},
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

  @spec run_deploy_env_vars(Manifest.Component.t(), String.t()) :: env_list()
  defp run_deploy_env_vars(%Manifest.Component{id: id, dir: dir}, checksum) do
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
