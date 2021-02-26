defmodule MBS.Workflow.Job do
  @moduledoc """
  Workflow job job logic
  """

  alias MBS.{Cache, Checksum, Config, Manifest}
  alias MBS.CLI.Reporter

  require Reporter.Status

  defmodule JobFunResult do
    @moduledoc """
    Job function result data
    """

    defstruct [:checksum, :targets]
  end

  def job_fun(reporter, %Config.Data{} = config, %Manifest.Data{name: name, job: job} = manifest) do
    fn job_id, upstream_results ->
      start_time = System.monotonic_time(:second)

      upstream_results = filter_upstream_results(upstream_results, job.dependencies)
      checksum = checksum(job.files, upstream_results)

      report_status =
        with :cache_miss <- cache_get_targets(config.cache.directory, name, checksum, job.targets),
             :ok <- job_command_exec(manifest, config.cache.directory, upstream_results),
             :ok <- assert_targets(job.targets),
             :ok <- cache_put_targets(config.cache.directory, name, checksum, job.targets) do
          Reporter.Status.ok()
        else
          :cached ->
            Reporter.Status.uptodate()

          {:error, reason} ->
            Reporter.Status.error(reason)
        end

      end_time = System.monotonic_time(:second)

      Reporter.job_report(reporter, job_id, report_status, end_time - start_time)

      unless report_status in [Reporter.Status.ok(), Reporter.Status.uptodate()] do
        raise "Job failed #{inspect(report_status)}"
      end

      %JobFunResult{checksum: checksum, targets: job.targets}
    end
  end

  def outdated_fun(reporter, %Config.Data{} = config, %Manifest.Data{name: name, job: job}) do
    fn job_id, upstream_results ->
      upstream_results = filter_upstream_results(upstream_results, job.dependencies)
      checksum = checksum(job.files, upstream_results)

      if not cache_hit_targets(config.cache.directory, name, checksum, job.targets) do
        Reporter.Status.outdated()
        Reporter.job_report(reporter, job_id, Reporter.Status.outdated(), nil)
      end

      %JobFunResult{checksum: checksum, targets: job.targets}
    end
  end

  defp cache_hit_targets(cache_directory, name, checksum, job_targets) do
    Enum.all?(job_targets, &Cache.hit(cache_directory, name, checksum, Path.basename(&1)))
  end

  defp cache_get_targets(cache_directory, name, checksum, job_targets) do
    found_all_targets = Enum.all?(job_targets, &(Cache.get(cache_directory, name, checksum, Path.basename(&1)) == :ok))

    if found_all_targets do
      :cached
    else
      :cache_miss
    end
  end

  defp cache_put_targets(cache_directory, name, checksum, job_targets) do
    Enum.each(job_targets, fn job_target ->
      dest_dir = Path.join([cache_directory, name, checksum])
      dest_target = Path.join(dest_dir, Path.basename(job_target))
      File.mkdir_p!(dest_dir)
      File.cp!(job_target, dest_target)
    end)

    :ok
  end

  defp filter_upstream_results(upstream_results, job_dependencies) do
    Enum.filter(upstream_results, fn {dependency_name, _} -> dependency_name in job_dependencies end)
    |> Map.new()
  end

  defp checksum(files, upstream_results) do
    files_checksum =
      files
      |> Enum.sort()
      |> Checksum.files_checksum()

    dependencies_checksums =
      upstream_results
      |> Enum.sort_by(fn {dependency_name, _} -> dependency_name end)
      |> Enum.map(fn {_dependency_name, %JobFunResult{checksum: dependency_checksum}} -> dependency_checksum end)

    [files_checksum | dependencies_checksums]
    |> Enum.join()
    |> Checksum.checksum()
  end

  defp job_command_exec(
         %Manifest.Data{dir: dir, job: %Manifest.Data.Job{} = job} = manifest,
         cache_directory,
         upstream_results
       ) do
    env = job_commands_env_vars(manifest, cache_directory, upstream_results)
    {command, args} = job_command(manifest, env)

    try do
      System.cmd(command, args, cd: dir, env: env, stderr_to_stdout: true)
    rescue
      error in [ErlangError] ->
        case error do
          %ErlangError{original: :enoent} ->
            {:error, "Unknown command #{inspect(command)}"}

          %ErlangError{original: :eaccess} ->
            {:error, "The command #{inspect(command)} does not point to an executable file"}
        end
    else
      {cmd_result, cmd_exit_status} ->
        if cmd_exit_status != 0 do
          {:error, "Command error #{inspect(job.command)}: exit status #{cmd_exit_status}\n\n#{cmd_result}"}
        else
          :ok
        end
    end
  end

  defp job_command(%Manifest.Data{} = manifest, env) do
    [command | args] =
      Enum.map(manifest.job.command, fn cmd ->
        Enum.reduce(env, cmd, fn {env_name, env_value}, cmd ->
          String.replace(cmd, "$#{env_name}", env_value)
        end)
      end)

    {command, args}
  end

  defp job_commands_env_vars(%Manifest.Data{} = manifest, cache_directory, upstream_results) do
    envs =
      Enum.map(manifest.job.dependencies, fn deps_name ->
        %JobFunResult{checksum: deps_checksum} = Map.fetch!(upstream_results, deps_name)

        shell_deps_name =
          deps_name
          |> String.upcase()
          |> String.replace(":", "_")

        deps_path = Cache.path(cache_directory, deps_name, deps_checksum)
        {"MBS_DEPS_#{shell_deps_name}", deps_path}
      end)

    [{"MBS_NAME", manifest.name}, {"MBS_CWD", manifest.dir} | envs]
  end

  defp assert_targets([]), do: :ok

  defp assert_targets(targets) do
    missing_targets = Enum.filter(targets, &(not File.exists?(&1)))

    if length(missing_targets) != 0 do
      {:error, "Missing targets #{inspect(missing_targets)}"}
    else
      :ok
    end
  end
end
