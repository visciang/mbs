defmodule MBS.Toolchain do
  @moduledoc """
  Toolchain functions
  """

  alias MBS.{Cache, Config, Docker, Manifest}
  alias MBS.CLI.Reporter
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec build(Manifest.Toolchain.t(), Reporter.t()) :: :ok | {:error, term()}
  def build(%Manifest.Toolchain{id: id, dir: dir, checksum: checksum, dockerfile: dockerfile}, reporter) do
    Docker.image_build(id, checksum, dir, dockerfile, reporter, "#{id}:build")
  end

  @spec shell_cmd(Manifest.Component.t(), String.t(), Config.Data.t(), Dask.Job.upstream_results()) :: String.t()
  def shell_cmd(
        %Manifest.Component{dir: work_dir, toolchain: toolchain} = component,
        checksum,
        %Config.Data{cache: %{dir: cache_dir}, root_dir: root_dir},
        upstream_results
      ) do
    env = run_env_vars(component, checksum, cache_dir, upstream_results)
    opts = run_opts(root_dir, work_dir) ++ ["--entrypoint", "sh", "--interactive"]

    Docker.image_run_cmd(toolchain.id, toolchain.checksum, opts, env)
  end

  @spec exec(
          Manifest.Component.t(),
          String.t(),
          Config.Data.t(),
          Dask.Job.upstream_results(),
          String.t(),
          Reporter.t()
        ) ::
          :ok | {:error, term()}
  def exec(
        %Manifest.Component{dir: work_dir, toolchain: toolchain, toolchain_opts: toolchain_opts} = component,
        checksum,
        %Config.Data{cache: %{dir: cache_dir}, root_dir: root_dir},
        upstream_results,
        job_id,
        reporter
      ) do
    env = run_env_vars(component, checksum, cache_dir, upstream_results)
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
             reporter,
             reporter_id
           ) do
        :ok ->
          Reporter.job_report(reporter, reporter_id, Reporter.Status.ok(), nil, Reporter.time() - start_time)
          {:cont, :ok}

        {:error, {cmd_result, cmd_exit_status}} ->
          Reporter.job_report(reporter, reporter_id, Reporter.Status.error(""), nil, Reporter.time() - start_time)
          {:halt, {:error, "exec error: exit status #{cmd_exit_status}\n\n#{cmd_result}"}}
      end
    end)
  end

  defp run_opts(root_dir, work_dir) do
    opts = ["--rm", "-t"]
    work_dir = ["-w", "#{work_dir}"]
    dir_mount = ["-v", "#{root_dir}:#{root_dir}"]

    opts ++ work_dir ++ dir_mount
  end

  defp run_env_vars(
         %Manifest.Component{id: id, dir: dir, dependencies: dependencies},
         checksum,
         cache_dir,
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

        deps_path = Cache.path(cache_dir, dep_id, dep_checksum, "")
        {"MBS_DEPS_#{shell_dep_id}", deps_path}
      end)

    [{"MBS_ID", id}, {"MBS_CWD", dir}, {"MBS_CHECKSUM", checksum} | env]
  end

  defp toolchain_opts_env_subs(toolchain_opts, env) do
    Enum.map(toolchain_opts, fn toolchain_opt ->
      Enum.reduce(env, toolchain_opt, fn {env_name, env_value}, toolchain_opt ->
        String.replace(toolchain_opt, "${#{env_name}}", env_value)
      end)
    end)
  end
end
