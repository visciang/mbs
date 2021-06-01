defmodule MBS.Toolchain.Common do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.{Config, Docker}
  alias MBS.Manifest.BuildDeploy

  require Reporter.Status

  @type env_list :: [{String.t(), String.t()}]

  @default_entrypoint "/toolchain.sh"

  @spec build(%Config.Data{}, BuildDeploy.Toolchain.t(), boolean()) :: :ok | {:error, term()}
  def build(
        %Config.Data{project: project},
        %BuildDeploy.Toolchain{
          id: id,
          dir: dir,
          checksum: checksum,
          dockerfile: dockerfile,
          docker_opts: docker_opts
        },
        force
      ) do
    docker_no_cache = if force, do: ["--no-cache"], else: []

    docker_labels = [
      "--label",
      "MBS_PROJECT_ID=#{project}",
      "--label",
      "MBS_ID=#{id}",
      "--label",
      "MBS_CHECKSUM=#{checksum}"
    ]

    docker_opts = docker_opts ++ docker_no_cache ++ docker_labels

    with {:build, :ok} <- {:build, Docker.image_build(docker_opts, id, checksum, dir, dockerfile, "#{id}:build")},
         {:entrypoint, {:ok, [@default_entrypoint]}} <- {:entrypoint, Docker.image_entrypoint(id, checksum)} do
      :ok
    else
      {:entrypoint, {:ok, bad_entrypoint}} ->
        {:error, "Bad toolchain entrypoint #{inspect(bad_entrypoint)}, expected #{inspect([@default_entrypoint])}"}

      {:entrypoint, err} ->
        err

      {:build, err} ->
        err
    end
  end

  @spec exec(BuildDeploy.Component.t(), env_list(), [String.t()]) :: :ok | {:error, String.t()}
  def exec(
        %BuildDeploy.Component{id: id, toolchain_opts: toolchain_opts},
        env,
        toolchain_steps
      ) do
    toolchain_opts = toolchain_opts_env_subs(toolchain_opts, env)

    Enum.reduce_while(toolchain_steps, :ok, fn toolchain_step, _ ->
      reporter_id = "#{id}:#{toolchain_step}"
      start_time = Reporter.time()

      case Docker.container_exec(id, [@default_entrypoint, toolchain_step | toolchain_opts], reporter_id) do
        :ok ->
          Reporter.job_report(reporter_id, Reporter.Status.ok(), nil, Reporter.time() - start_time)
          {:cont, :ok}

        {:error, {cmd_result, cmd_exit_status}} ->
          Reporter.job_report(reporter_id, Reporter.Status.error(""), nil, Reporter.time() - start_time)
          {:halt, {:error, "exec error: exit status #{inspect(cmd_exit_status)}\n\n#{inspect(cmd_result)}"}}
      end
    end)
  end

  @spec toolchain_opts_env_subs([String.t()], env_list()) :: [String.t()]
  defp toolchain_opts_env_subs(toolchain_opts, env) do
    Enum.map(toolchain_opts, fn toolchain_opt ->
      Enum.reduce(env, toolchain_opt, fn {env_name, env_value}, toolchain_opt ->
        String.replace(toolchain_opt, "${#{env_name}}", env_value)
      end)
    end)
  end
end
