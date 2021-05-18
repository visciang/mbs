defmodule MBS.Docker do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Utils
  require MBS.CLI.Reporter.Status

  @type env_list :: [{String.t(), String.t()}]

  @cmd_arg_dind ["-v", "/var/run/docker.sock:/var/run/docker.sock"]

  @spec image_id(String.t(), String.t()) :: {:ok, nil | String.t()} | {:error, term()}
  def image_id(repository, tag) do
    cmd_args = ["image", "ls", "-q", "#{repository}:#{tag}"]

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {"", 0} -> {:ok, nil}
      {res, 0} -> {:ok, String.trim(res)}
      {res, _} -> {:error, res}
    end
  end

  @spec image_entrypoint(String.t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def image_entrypoint(repository, tag) do
    cmd_args = ["image", "inspect", "#{repository}:#{tag}"]

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {res, 0} ->
        [inspected] = Jason.decode!(res)
        {:ok, inspected["Config"]["Entrypoint"]}

      {res, _} ->
        {:error, res}
    end
  end

  @spec image_exists(String.t(), String.t()) :: boolean()
  def image_exists(repository, tag) do
    case image_id(repository, tag) do
      {:ok, id} when is_binary(id) -> true
      _ -> false
    end
  end

  @spec image_tag(String.t(), String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def image_tag(s_image, s_tag, d_image, d_tag) do
    cmd_args = ["image", "tag", "#{s_image}:#{s_tag}", "#{d_image}:#{d_tag}"]

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  @spec image_save(String.t(), String.t(), Path.t(), String.t()) :: :ok | {:error, term()}
  def image_save(repository, tag, out_dir, job_id) do
    cmd_args = ["image", "save", "#{repository}:#{tag}"]
    image_file_path = Path.join(out_dir, "#{repository}.tar.gz")

    docker_debug(job_id, cmd_args)

    case System.cmd("docker", cmd_args, stderr_to_stdout: true, into: File.stream!(image_file_path, [:compressed])) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  @spec image_load(Path.t(), String.t()) :: :ok | {:error, term()}
  def image_load(path_tar_gz, job_id) do
    path_tar = Path.join(System.tmp_dir!(), Path.basename(path_tar_gz, ".gz"))
    Utils.gunzip(path_tar_gz, path_tar)

    cmd_args = ["image", "load", "--input", path_tar]

    docker_debug(job_id, cmd_args)

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  @spec image_build([String.t()], String.t(), String.t(), Path.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def image_build(docker_opts, repository, tag, dir, dockerfile, job_id) do
    cmd_args = ["image", "build", "--rm"] ++ docker_opts ++ ["--tag", "#{repository}:#{tag}", "-f", dockerfile, "."]
    cmd_into = %Reporter.Log{job_id: job_id}

    docker_debug(job_id, cmd_args)

    case System.cmd("docker", cmd_args, cd: dir, stderr_to_stdout: true, into: cmd_into) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  @spec image_pull(String.t(), String.t()) :: :ok | {:error, term()}
  def image_pull(repository, tag) do
    cmd_args = ["image", "pull", "#{repository}:#{tag}"]

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  @spec image_push(String.t(), String.t()) :: :ok | {:error, term()}
  def image_push(repository, tag) do
    cmd_args = ["image", "push", "#{repository}:#{tag}"]

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  @spec container_stop(String.t(), String.t()) :: :ok | {:error, {term(), pos_integer()}}
  def container_stop(container_id, job_id) do
    cmd_args = ["container", "stop", container_id]
    cmd_into = %Reporter.Log{job_id: job_id}

    docker_debug(job_id, cmd_args)

    case System.cmd("docker", cmd_args, stderr_to_stdout: true, into: cmd_into) do
      {_, 0} -> :ok
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec container_exec(String.t(), [String.t()], String.t()) :: :ok | {:error, {term(), pos_integer()}}
  def container_exec(container_id, command, job_id) do
    cmd_args = ["container", "exec", "-t", container_id | command]
    cmd_into = %Reporter.Log{job_id: job_id}

    docker_debug(job_id, cmd_args)

    case System.cmd("docker", cmd_args, stderr_to_stdout: true, into: cmd_into) do
      {_, 0} -> :ok
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec container_dput(String.t(), Path.t(), Path.t(), String.t()) :: :ok | {:error, {term(), pos_integer()}}
  def container_dput(container_id, src_dir, dest_dir, job_id) do
    cmd_args = ["-c", "tar -O -h -C \"#{src_dir}\" -c . | docker cp - #{container_id}:#{dest_dir}"]

    docker_debug(job_id, cmd_args)

    case System.cmd("sh", cmd_args) do
      {_, 0} -> :ok
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec container_dget(String.t(), Path.t(), Path.t(), String.t()) :: :ok | {:error, {term(), pos_integer()}}
  def container_dget(container_id, src_dir, dest_dir, job_id) do
    cmd_args = ["-c", "docker cp #{container_id}:#{src_dir} | tar -C \"#{dest_dir}\" -xf -"]

    docker_debug(job_id, cmd_args)

    case System.cmd("sh", cmd_args) do
      {_, 0} -> :ok
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec container_put(String.t(), Path.t(), Path.t(), String.t()) :: :ok | {:error, {term(), pos_integer()}}
  def container_put(container_id, src, dest, job_id) do
    cmd_args = ["cp", dest, "#{container_id}:#{src}"]

    docker_debug(job_id, cmd_args)

    case System.cmd("docker", cmd_args) do
      {_, 0} -> :ok
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec container_get(String.t(), Path.t(), Path.t(), String.t()) :: :ok | {:error, {term(), pos_integer()}}
  def container_get(container_id, src, dest, job_id) do
    cmd_args = ["cp", "#{container_id}:#{src}", dest]

    docker_debug(job_id, cmd_args)

    case System.cmd("docker", cmd_args) do
      {_, 0} -> :ok
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec container_run(String.t(), String.t(), [String.t()], env_list(), [String.t()], String.t()) ::
          :ok | {:error, {term(), pos_integer()}}
  def container_run(repository, tag, opts, env, command, job_id) do
    cmd_args = container_run_cmd_args(repository, tag, opts, env) ++ command
    cmd_into = %Reporter.Log{job_id: job_id}

    docker_debug(job_id, cmd_args)

    case System.cmd("docker", cmd_args, env: env, stderr_to_stdout: true, into: cmd_into) do
      {_, 0} -> :ok
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec container_run_cmd(String.t(), String.t(), [String.t()], env_list()) :: String.t()
  def container_run_cmd(repository, tag, opts, env) do
    ["docker" | container_run_cmd_args(repository, tag, opts, env)]
    |> Enum.join(" ")
  end

  @spec container_run_cmd_args(String.t(), String.t(), [String.t()], env_list()) :: [String.t()]
  defp container_run_cmd_args(repository, tag, opts, env) do
    ["container", "run", "--init"] ++ opts ++ @cmd_arg_dind ++ docker_env(env) ++ ["#{repository}:#{tag}"]
  end

  @spec docker_env(env_list()) :: [String.t()]
  defp docker_env(env) do
    Enum.flat_map(env, fn {env_name, env_value} -> ["-e", "#{env_name}=#{env_value}"] end)
  end

  @spec docker_debug(String.t(), [String.t()]) :: :ok
  defp docker_debug(job_id, cmd_args) do
    if Logger.level() == :debug do
      Reporter.job_report(job_id, Reporter.Status.log(), "docker #{inspect(cmd_args)}", nil)
    end

    :ok
  end
end
