defmodule MBS.Toolchain do
  @moduledoc """
  Toolchain functions
  """

  alias MBS.{Cache, Docker, Manifest}
  alias MBS.CLI.Reporter
  alias MBS.Workflow.Job.JobFunResult

  require Reporter.Status

  def build(%Manifest.Toolchain{id: id, dir: dir, checksum: checksum, dockerfile: dockerfile}, reporter, logs_enabled) do
    Docker.image_build(id, checksum, dir, dockerfile, reporter, "#{id}:build", logs_enabled)
  end

  def shell_cmd(
        %Manifest.Component{dir: work_directory, toolchain: toolchain} = component,
        checksum,
        root_directory,
        cache_directory,
        upstream_results
      ) do
    env = run_env_vars(component, checksum, cache_directory, upstream_results)
    opts = run_opts(root_directory, work_directory) ++ ["--entrypoint", "sh", "--interactive"]

    Docker.image_run_cmd(toolchain.id, toolchain.checksum, opts, env)
  end

  def exec(
        %Manifest.Component{dir: work_directory, toolchain: toolchain, toolchain_opts: toolchain_opts} = component,
        checksum,
        root_directory,
        cache_directory,
        upstream_results,
        job_id,
        reporter,
        logs_enabled
      ) do
    env = run_env_vars(component, checksum, cache_directory, upstream_results)
    opts = run_opts(root_directory, work_directory)

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
             reporter_id,
             logs_enabled
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
         cache_directory,
         upstream_results
       ) do
    env =
      Enum.map(dependencies, fn dep_id ->
        %JobFunResult{checksum: dep_checksum} = Map.fetch!(upstream_results, dep_id)

        shell_dep_id =
          dep_id
          |> String.upcase()
          |> String.replace(":", "_")
          |> String.replace("-", "_")

        deps_path = Cache.path(cache_directory, dep_id, dep_checksum, "")
        {"MBS_DEPS_#{shell_dep_id}", deps_path}
      end)

    [{"MBS_ID", id}, {"MBS_CWD", dir}, {"MBS_CHECKSUM", checksum} | env]
  end
end
