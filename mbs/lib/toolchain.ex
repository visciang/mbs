defmodule MBS.Toolchain do
  @moduledoc """
  Toolchain functions
  """

  alias MBS.{Cache, Config, Const, Docker, Manifest}
  alias MBS.CLI.Reporter
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec build(Manifest.Toolchain.t()) :: :ok | {:error, term()}
  def build(%Manifest.Toolchain{id: id, dir: dir, checksum: checksum, dockerfile: dockerfile}) do
    Docker.image_build(id, checksum, dir, dockerfile, "#{id}:build")
  end

  @spec shell_cmd(Manifest.Component.t(), String.t(), Config.Data.t(), Dask.Job.upstream_results()) :: String.t()
  def shell_cmd(
        %Manifest.Component{dir: work_dir, toolchain: toolchain} = component,
        checksum,
        %Config.Data{root_dir: root_dir},
        upstream_results
      ) do
    env = run_build_env_vars(component, root_dir, checksum, upstream_results)
    opts = run_opts(root_dir, work_dir) ++ ["--entrypoint", "sh", "--interactive"]

    Docker.image_run_cmd(toolchain.id, toolchain.checksum, opts, env)
  end

  @spec exec_build(Manifest.Component.t(), String.t(), Config.Data.t(), Dask.Job.upstream_results(), String.t()) ::
          :ok | {:error, term()}
  def exec_build(
        %Manifest.Component{} = component,
        checksum,
        %Config.Data{root_dir: root_dir} = config,
        upstream_results,
        job_id
      ) do
    env = run_build_env_vars(component, root_dir, checksum, upstream_results)
    exec(component, config, env, job_id)
  end

  @spec exec_deploy(Manifest.Component.t(), String.t(), Config.Data.t(), String.t()) ::
          :ok | {:error, term()}
  def exec_deploy(%Manifest.Component{} = component, checksum, %Config.Data{} = config, job_id) do
    env = run_deploy_env_vars(component, checksum)
    exec(component, config, env, job_id)
  end

  defp exec(
         %Manifest.Component{dir: work_dir, toolchain: toolchain, toolchain_opts: toolchain_opts},
         %Config.Data{root_dir: root_dir},
         env,
         job_id
       ) do
    toolchain_opts = toolchain_opts_env_subs(toolchain_opts, env)
    opts = run_opts(root_dir, work_dir)

    Enum.reduce_while(toolchain.steps, nil, fn toolchain_step, _ ->
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

  defp run_opts(root_dir, work_dir) do
    opts = ["--rm", "-t"]
    work_dir = ["-w", "#{work_dir}"]
    dir_mount = ["-v", "#{root_dir}:#{root_dir}"]

    opts ++ work_dir ++ dir_mount
  end

  defp run_build_env_vars(
         %Manifest.Component{id: id, dir: dir, dependencies: dependencies},
         root_dir,
         checksum,
         upstream_results
       ) do
    env =
      Enum.flat_map(dependencies, fn dep_id ->
        %Job.FunResult{checksum: dep_checksum} = Map.fetch!(upstream_results, dep_id)

        shell_dep_id =
          dep_id
          |> String.upcase()
          |> String.replace(":", "_")
          |> String.replace("-", "_")

        cache_dir = Path.join(root_dir, Const.cache_dir())
        deps_path = Cache.path(cache_dir, dep_id, dep_checksum, "")
        [{"MBS_DIR_#{shell_dep_id}", deps_path}, {"MBS_CHECKSUM_#{shell_dep_id}", dep_checksum}]
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
