defmodule MBS.Toolchain.RunDeploy do
  @moduledoc false

  alias MBS.{Const, Docker, Toolchain}
  alias MBS.Manifest.BuildDeploy

  @type opts :: [String.t()]
  @type env_list :: [{String.t(), String.t()}]

  @sh_sleep_forever_cmd ["-c", "while true; do sleep 2; done"]

  @spec up(Path.t(), BuildDeploy.Component.t(), String.t()) :: {:ok, env_list()} | {:error, term()}
  def up(work_dir, %BuildDeploy.Component{id: id, toolchain: toolchain} = component, checksum) do
    envs = env_vars(component, checksum)
    run_opts_ = run_opts(work_dir, component) ++ ["--detach", "--name", id, "--entrypoint", "sh"]

    case Docker.container_run(toolchain.id, toolchain.checksum, run_opts_, envs, @sh_sleep_forever_cmd, id) do
      :ok -> {:ok, envs}
      error -> error
    end
  end

  @spec down(BuildDeploy.Component.t()) :: :ok | {:error, term()}
  def down(%BuildDeploy.Component{id: id}) do
    Docker.container_stop(id, id)
  end

  @spec exec(BuildDeploy.Component.t(), env_list()) :: :ok | {:error, String.t()}
  def exec(%BuildDeploy.Component{} = component, envs) do
    Toolchain.Common.exec(component, envs, component.toolchain.steps)
  end

  @spec exec_destroy(BuildDeploy.Component.t(), env_list()) :: :ok | {:error, String.t()}
  def exec_destroy(%BuildDeploy.Component{} = component, envs) do
    component = put_in(component.toolchain.steps, ["destroy"])
    Toolchain.Common.exec(component, envs, component.toolchain.destroy_steps)
  end

  @spec run_opts(Path.t(), BuildDeploy.Component.t()) :: opts()
  defp run_opts(work_dir, %BuildDeploy.Component{docker_opts: docker_opts}) do
    opts = ["--rm", "-t" | Map.get(docker_opts, :run, [])]
    opts_work_dir = ["-w", "#{work_dir}"]
    opts_dir_mount = ["-v", "#{Const.releases_dir()}:#{Const.releases_dir()}:ro"]

    opts ++ opts_work_dir ++ opts_dir_mount
  end

  @spec env_vars(BuildDeploy.Component.t(), String.t()) :: env_list()
  defp env_vars(%BuildDeploy.Component{id: id, dir: dir}, checksum) do
    [{"MBS_ID", id}, {"MBS_CWD", dir}, {"MBS_CHECKSUM", checksum}]
  end
end
