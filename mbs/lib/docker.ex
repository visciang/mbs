defmodule MBS.Docker do
  @moduledoc false

  alias MBS.CLI.Reporter
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

  @spec image_exists(String.t(), String.t()) :: boolean()
  def image_exists(repository, tag) do
    case image_id(repository, tag) do
      {:ok, id} when is_binary(id) -> true
      _ -> false
    end
  end

  @spec image_save(String.t(), String.t(), Path.t(), String.t()) :: :ok | {:error, term()}
  def image_save(repository, tag, out_dir, job_id) do
    cmd_args = ["image", "save", "#{repository}:#{tag}"]
    image_file_path = Path.join(out_dir, "#{repository}.tar.gz")

    Reporter.job_report(job_id, Reporter.Status.log(), "docker #{inspect(cmd_args)}", nil)

    case System.cmd("docker", cmd_args, stderr_to_stdout: true, into: File.stream!(image_file_path, [:compressed])) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  @spec image_load(Path.t(), String.t()) :: :ok | {:error, term()}
  def image_load(path_tar_gz, job_id) do
    path_tar = Path.join(System.tmp_dir!(), Path.basename(path_tar_gz, ".gz"))
    gunzip(path_tar_gz, path_tar)

    cmd_args = ["image", "load", "--input", path_tar]

    Reporter.job_report(job_id, Reporter.Status.log(), "docker #{inspect(cmd_args)}", nil)

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  @spec image_build([String.t()], String.t(), String.t(), Path.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def image_build(docker_opts, repository, tag, dir, dockerfile, job_id) do
    cmd_args = ["image", "build", "--rm", "-t"] ++ docker_opts ++ ["#{repository}:#{tag}", "-f", dockerfile, "."]
    cmd_into = %Reporter.Log{job_id: job_id}

    if Logger.level() == :debug do
      Reporter.job_report(job_id, Reporter.Status.log(), "docker #{inspect(cmd_args)}", nil)
    end

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

  @spec image_run(String.t(), String.t(), [String.t()], env_list(), [String.t()], String.t()) ::
          :ok | {:error, {term(), pos_integer()}}
  def image_run(repository, tag, opts, env, command, job_id) do
    cmd_args = ["run"] ++ opts ++ @cmd_arg_dind ++ docker_env(env) ++ ["#{repository}:#{tag}"] ++ command
    cmd_into = %Reporter.Log{job_id: job_id}

    if Logger.level() == :debug do
      Reporter.job_report(job_id, Reporter.Status.log(), "docker #{inspect(cmd_args)}", nil)
    end

    case System.cmd("docker", cmd_args, env: env, stderr_to_stdout: true, into: cmd_into) do
      {_, 0} -> :ok
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec image_run_cmd(String.t(), String.t(), [String.t()], env_list()) :: String.t()
  def image_run_cmd(repository, tag, opts, env) do
    (["docker", "run"] ++ opts ++ @cmd_arg_dind ++ docker_env(env) ++ ["#{repository}:#{tag}"])
    |> Enum.join(" ")
  end

  @spec compose(:up | :down, Path.t(), env_list(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def compose(action, compose_file, env, job_id) do
    compose_project_name = String.replace(job_id, ":", "")
    cmd_action = if action == :up, do: ["up", "-d"], else: ["down", "--volumes", "--remove-orphans"]
    cmd_args = ["--project-name", compose_project_name, "-f", compose_file | cmd_action]
    cmd_into = %Reporter.Log{job_id: "#{job_id}_#{action}"}

    docker_network_name = "#{compose_project_name}_default"

    case System.cmd("docker-compose", cmd_args, env: env, stderr_to_stdout: true, into: cmd_into) do
      {_, 0} -> {:ok, docker_network_name}
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec compose_cmd(:up | :down, Path.t(), env_list(), String.t()) :: {:ok, String.t(), String.t()} | {:error, term()}
  def compose_cmd(action, compose_file, env, job_id) do
    compose_project_name = String.replace(job_id, ":", "")
    cmd_action = if action == :up, do: ["up", "-d"], else: ["down", "--volumes", "--remove-orphans"]
    cmd_args = ["--project-name", compose_project_name, "-f", compose_file | cmd_action]
    env_cmd = Enum.map(env, fn {name, value} -> "#{name}='#{value}'" end)

    docker_network_name = "#{compose_project_name}_default"
    cmd = (env_cmd ++ ["docker-compose"] ++ cmd_args) |> Enum.join(" ")

    {:ok, docker_network_name, cmd}
  end

  @spec docker_env(env_list()) :: [String.t()]
  defp docker_env(env) do
    Enum.flat_map(env, fn {env_name, env_value} -> ["-e", "#{env_name}=#{env_value}"] end)
  end

  @spec gunzip(Path.t(), Path.t()) :: :ok
  defp gunzip(src, dest) do
    src
    |> File.stream!([:compressed], 2048)
    |> Stream.into(File.stream!(dest, [], 2048))
    |> Stream.run()
  end
end
