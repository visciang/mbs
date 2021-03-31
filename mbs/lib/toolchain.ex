defmodule MBS.Toolchain do
  @moduledoc """
  Toolchain functions
  """

  alias MBS.CLI.Reporter
  alias MBS.{Config, Docker, Manifest, Utils}
  alias MBS.Workflow.Job

  require Reporter.Status

  @local_dependencies_targets_dir ".deps"

  @spec build(Manifest.Toolchain.t()) :: :ok | {:error, term()}
  def build(%Manifest.Toolchain{id: id, dir: dir, checksum: checksum, dockerfile: dockerfile, docker_opts: docker_opts}) do
    Docker.image_build(docker_opts, id, checksum, dir, dockerfile, "#{id}:build")
  end

  @spec shell_cmd(Manifest.Component.t(), String.t(), Config.Data.t(), Dask.Job.upstream_results()) :: String.t()
  def shell_cmd(
        %Manifest.Component{dir: work_dir, toolchain: toolchain, docker_opts: docker_opts} = component,
        checksum,
        %Config.Data{root_dir: root_dir},
        upstream_results
      ) do
    env = run_build_env_vars(component, checksum, upstream_results)
    opts = run_opts(docker_opts, root_dir, work_dir) ++ ["--entrypoint", "sh", "--interactive"]

    Docker.image_run_cmd(toolchain.id, toolchain.checksum, opts, env)
  end

  @spec exec_build(Manifest.Component.t(), String.t(), Config.Data.t(), Dask.Job.upstream_results(), String.t()) ::
          :ok | {:error, term()}
  def exec_build(%Manifest.Component{} = component, checksum, %Config.Data{} = config, upstream_results, job_id) do
    get_dependencies_targets(component, config, upstream_results)
    env = run_build_env_vars(component, checksum, upstream_results)
    exec(component, config, env, job_id, component.toolchain.steps)
  end

  @spec exec_deploy(Manifest.Component.t(), String.t(), Config.Data.t(), String.t()) ::
          :ok | {:error, term()}
  def exec_deploy(%Manifest.Component{} = component, checksum, %Config.Data{} = config, job_id) do
    env = run_deploy_env_vars(component, checksum)
    exec(component, config, env, job_id, component.toolchain.steps)
  end

  @spec exec_destroy(Manifest.Component.t(), String.t(), Config.Data.t(), String.t()) ::
          :ok | {:error, term()}
  def exec_destroy(%Manifest.Component{} = component, checksum, %Config.Data{} = config, job_id) do
    env = run_deploy_env_vars(component, checksum)
    component = put_in(component.toolchain.steps, ["destroy"])
    exec(component, config, env, job_id, component.toolchain.destroy_steps)
  end

  defp exec(
         %Manifest.Component{
           dir: work_dir,
           toolchain: toolchain,
           toolchain_opts: toolchain_opts,
           docker_opts: docker_opts
         },
         %Config.Data{root_dir: root_dir},
         env,
         job_id,
         toolchain_steps
       ) do
    toolchain_opts = toolchain_opts_env_subs(toolchain_opts, env)
    opts = run_opts(docker_opts, root_dir, work_dir)

    Enum.reduce_while(toolchain_steps, nil, fn toolchain_step, _ ->
      reporter_id = "#{job_id}:#{toolchain_step}"
      start_time = Reporter.time()

      case Docker.image_run(
             toolchain.id,
             toolchain.checksum,
             opts,
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

  defp run_opts(docker_opts, _root_dir, work_dir) do
    opts = ["--rm", "-t" | docker_opts]
    work_dir_opts = ["-w", "#{work_dir}"]
    dir_mount_opts = ["-v", "#{work_dir}:#{work_dir}"]

    opts ++ work_dir_opts ++ dir_mount_opts
  end

  defp get_dependencies_targets(
         %Manifest.Component{dir: dir},
         %Config.Data{root_dir: root_dir},
         upstream_results
       ) do
    local_dependencies_targets_dir = Path.join(dir, @local_dependencies_targets_dir)
    File.rm_rf!(local_dependencies_targets_dir)
    File.mkdir!(local_dependencies_targets_dir)

    upstream_targets_set =
      upstream_results
      |> Map.values()
      |> Enum.map(& &1.targets)
      |> Utils.union_mapsets()

    Enum.each(upstream_targets_set, fn
      {dep_id, %Manifest.Target{type: :file, target: target_cache_path}} ->
        target_cache_path = Path.join(root_dir, target_cache_path)

        dest_dependency_dir = Path.join(local_dependencies_targets_dir, dep_id)
        dest_dependency_path = Path.join(dest_dependency_dir, Path.basename(target_cache_path))

        File.mkdir_p!(dest_dependency_dir)
        File.cp!(target_cache_path, dest_dependency_path)

      {_dep_id, %Manifest.Target{type: :docker}} ->
        :ok
    end)
  end

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

  defp run_deploy_env_vars(%Manifest.Component{id: id, dir: dir}, checksum) do
    [{"MBS_ID", id}, {"MBS_CWD", dir}, {"MBS_CHECKSUM", checksum}]
  end

  defp toolchain_opts_env_subs(toolchain_opts, env) do
    Enum.map(toolchain_opts, fn toolchain_opt ->
      Enum.reduce(env, toolchain_opt, fn {env_name, env_value}, toolchain_opt ->
        String.replace(toolchain_opt, "${#{env_name}}", env_value)
      end)
    end)
  end
end
