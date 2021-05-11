defmodule MBS.DockerCompose do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Docker

  @type compose_action :: :up | :down

  @spec compose(compose_action(), Path.t(), Docker.env_list(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def compose(action, compose_file, env, job_id) do
    {cmd_args, docker_network_name} = args(action, compose_file, job_id)
    cmd_into = %Reporter.Log{job_id: "#{job_id}_#{action}"}

    case System.cmd("docker-compose", cmd_args, env: env, stderr_to_stdout: true, into: cmd_into) do
      {_, 0} -> {:ok, docker_network_name}
      {res, exit_status} -> {:error, {res, exit_status}}
    end
  end

  @spec compose_cmd(compose_action(), Path.t(), Docker.env_list(), String.t()) :: {:ok, String.t(), String.t()}
  def compose_cmd(action, compose_file, env, job_id) do
    {cmd_args, docker_network_name} = args(action, compose_file, job_id)
    env_cmd = Enum.map(env, fn {name, value} -> "#{name}='#{value}'" end)
    cmd = (env_cmd ++ ["docker-compose"] ++ cmd_args) |> Enum.join(" ")

    {:ok, docker_network_name, cmd}
  end

  @spec args(compose_action(), Path.t(), String.t()) :: {[String.t()], String.t()}
  defp args(action, compose_file, job_id) do
    cmd_action =
      case action do
        :up -> ["up", "-d"]
        :down -> ["down", "--volumes", "--remove-orphans"]
      end

    compose_project_name = String.replace(job_id, ":", "")
    cmd_args = ["--project-name", compose_project_name, "-f", compose_file | cmd_action]

    docker_network_name = "#{compose_project_name}_default"

    {cmd_args, docker_network_name}
  end
end
