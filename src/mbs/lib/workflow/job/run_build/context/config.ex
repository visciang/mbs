defmodule MBS.Workflow.Job.RunBuild.Context.Config do
  @moduledoc false

  alias MBS.{Const, Docker, Utils}
  alias MBS.Manifest.BuildDeploy

  @spec put(BuildDeploy.Component.t(), boolean()) :: :ok | {:error, term()}
  def put(%BuildDeploy.Component{}, false), do: :ok

  def put(%BuildDeploy.Component{id: id, project_dir: project_dir}, true) do
    temp_dir = Utils.mktemp()
    temp_project_dir = Path.join(temp_dir, project_dir)

    File.mkdir_p!(temp_project_dir)

    [Const.config_file(), Const.manifest_project_filename()]
    |> Enum.each(&File.ln_s!(Path.join(project_dir, &1), Path.join(temp_project_dir, &1)))

    Docker.container_dput(id, temp_dir, "/", id)
  end
end
