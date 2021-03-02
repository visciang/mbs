defmodule MBS.Docker do
  @moduledoc false

  alias MBS.Utils

  def image_exists(repository, tag) do
    cmd_args = ["image", "ls", "-q", "#{repository}:#{tag}"]

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {"", 0} ->
        false

      {_, 0} ->
        true

      {res, _} ->
        error_message = IO.ANSI.format([:red, "docker cmd #{inspect(cmd_args)} failed\n#{res}"], true)
        Utils.halt(error_message)
    end
  end

  def image_build(repository, tag, dir, dockerfile) do
    cmd_args = ["image", "build", "--rm", "-t", "#{repository}:#{tag}", "-f", dockerfile, "."]

    case System.cmd("docker", cmd_args, cd: dir, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {res, _} -> {:error, res}
    end
  end

  def image_pull(repository, tag) do
    cmd_args = ["image", "pull", "#{repository}:#{tag}"]

    case System.cmd("docker", cmd_args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {res, _} ->
        {:error, res}
    end
  end

  def image_run(repository, tag, opts, env, command) do
    env_opt = Enum.flat_map(env, fn {env_name, env_value} -> ["-e", "#{env_name}=#{env_value}"] end)
    cmd_args = ["run"] ++ opts ++ env_opt ++ ["#{repository}:#{tag}"] ++ command

    case System.cmd("docker", cmd_args, env: env, stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {res, exit_status} ->
        {:error, {res, exit_status}}
    end
  end
end
