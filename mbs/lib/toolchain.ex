defmodule MBS.Toolchain do
  @moduledoc """
  Toolchain functions
  """

  alias MBS.{Cache, Docker, Manifest}
  alias MBS.CLI.Reporter
  alias MBS.Workflow.Job.JobFunResult

  require Reporter.Status

  def build(%Manifest.Toolchain{id: id, dir: dir, checksum: checksum, dockerfile: dockerfile}) do
    Docker.image_build(id, checksum, dir, dockerfile)
  end

  def exec(
        %Manifest.Component{toolchain: toolchain} = component,
        cache_directory,
        upstream_results,
        job_id,
        reporter
      ) do
    env = env_vars(component, cache_directory, upstream_results)
    {command, args} = cmd(component, cache_directory, env)

    Enum.reduce_while(toolchain.steps, nil, fn toolchain_step, _ ->
      reporter_id = "#{job_id}:#{toolchain_step}"
      start_time = Reporter.time()

      try do
        System.cmd(command, args ++ [toolchain_step], env: env, stderr_to_stdout: true)
      rescue
        error ->
          Reporter.job_report(reporter, reporter_id, Reporter.Status.error(""), nil, Reporter.time() - start_time)
          {:halt, {:error, "#{inspect(error)}"}}
      else
        {_, 0} ->
          Reporter.job_report(reporter, reporter_id, Reporter.Status.ok(), nil, Reporter.time() - start_time)
          {:cont, :ok}

        {cmd_result, cmd_exit_status} ->
          Reporter.job_report(reporter, reporter_id, Reporter.Status.error(""), nil, Reporter.time() - start_time)
          {:halt, {:error, "Command error #{inspect(command)}: exit status #{cmd_exit_status}\n\n#{cmd_result}"}}
      end
    end)
  end

  defp cmd(%Manifest.Component{dir: dir, toolchain: toolchain}, cache_directory, env) do
    run = ["run", "--rm", "-t"]
    work_dir = ["-w", "#{dir}"]
    dir_mount = ["-v", "#{dir}:#{dir}"]
    cache_mount = ["-v", "#{cache_directory}:/cache"]
    img = ["#{toolchain.id}:#{toolchain.checksum}"]
    env = Enum.flat_map(env, fn {env_name, env_value} -> ["-e", "#{env_name}=#{env_value}"] end)

    {"docker", run ++ work_dir ++ dir_mount ++ cache_mount ++ env ++ img}
  end

  defp env_vars(
         %Manifest.Component{id: id, dir: dir, dependencies: dependencies},
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

        deps_path = Cache.path(cache_directory, dep_id, dep_checksum)
        {"MBS_DEPS_#{shell_dep_id}", deps_path}
      end)

    [{"MBS_ID", id}, {"MBS_CWD", dir} | env]
  end
end
