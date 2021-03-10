defmodule MBS.Docker do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Utils
  require MBS.CLI.Reporter.Status

  @cmd_arg_dind ["-v", "/var/run/docker.sock:/var/run/docker.sock"]

  @spec image_id(String.t(), String.t()) :: nil | String.t()
  def image_id(repository, tag) do
    cmd_args = ["image", "ls", "-q", "#{repository}:#{tag}"]

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {"", 0} ->
        nil

      {res, 0} ->
        String.trim(res)

      {res, _} ->
        error_message = IO.ANSI.format([:red, "docker cmd #{inspect(cmd_args)} failed\n#{res}"], true)
        Utils.halt(error_message)
    end
  end

  @spec image_exists(String.t(), String.t()) :: boolean()
  def image_exists(repository, tag) do
    image_id(repository, tag) != nil
  end

  @spec image_build(String.t(), String.t(), Path.t(), String.t(), Reporter.t(), String.t(), boolean) ::
          :ok | {:error, term()}
  def image_build(repository, tag, dir, dockerfile, reporter, job_id, logs_enabled) do
    cmd_args = ["image", "build", "--rm", "-t", "#{repository}:#{tag}", "-f", dockerfile, "."]
    cmd_into = if logs_enabled, do: %Reporter.Log{reporter: reporter, job_id: job_id}, else: ""

    if logs_enabled do
      Reporter.job_report(reporter, job_id, Reporter.Status.log(), "docker #{inspect(cmd_args)}", nil)
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
      {_, 0} ->
        :ok

      {res, _} ->
        {:error, res}
    end
  end

  @spec image_run(
          String.t(),
          String.t(),
          [String.t()],
          [{String.t(), String.t()}],
          [String.t()],
          Reporter.t(),
          String.t(),
          boolean()
        ) :: :ok | {:error, {term(), pos_integer()}}
  def image_run(repository, tag, opts, env, command, reporter, job_id, logs_enabled) do
    cmd_args = ["run"] ++ opts ++ @cmd_arg_dind ++ docker_env(env) ++ ["#{repository}:#{tag}"] ++ command
    cmd_into = if logs_enabled, do: %Reporter.Log{reporter: reporter, job_id: job_id}, else: ""

    if logs_enabled do
      Reporter.job_report(reporter, job_id, Reporter.Status.log(), "docker #{inspect(cmd_args)}", nil)
    end

    case System.cmd("docker", cmd_args, env: env, stderr_to_stdout: true, into: cmd_into) do
      {_, 0} ->
        :ok

      {res, exit_status} ->
        {:error, {res, exit_status}}
    end
  end

  @spec image_run_cmd(String.t(), String.t(), [String.t()], [{String.t(), String.t()}]) :: String.t()
  def image_run_cmd(repository, tag, opts, env) do
    (["docker", "run"] ++ opts ++ @cmd_arg_dind ++ docker_env(env) ++ ["#{repository}:#{tag}"])
    |> Enum.join(" ")
  end

  defp docker_env(env) do
    Enum.flat_map(env, fn {env_name, env_value} -> ["-e", "#{env_name}=#{env_value}"] end)
  end
end
