defmodule MBS.Workflow.Job.RunBuild.Context.Files do
  @moduledoc false

  alias MBS.Docker
  alias MBS.Manifest.BuildDeploy
  alias MBS.Utils

  @spec put(BuildDeploy.Component.t(), [BuildDeploy.Component.t()], boolean()) :: :ok | {:error, term()}
  def put(_component, _upstream_components, false), do: :ok

  def put(%BuildDeploy.Component{id: id} = component, upstream_components, true) do
    temp_dir = Utils.mktemp()

    [component | upstream_components]
    |> Enum.each(fn %BuildDeploy.Component{files: files} ->
      files
      |> paths_dirname()
      |> Enum.each(&File.mkdir_p!(Path.join(temp_dir, &1)))

      Enum.each(files, &File.ln_s!(&1, Path.join(temp_dir, &1)))
    end)

    Docker.container_dput(id, temp_dir, "/", id)
  end

  @spec paths_dirname([Path.t()]) :: MapSet.t(Path.t())
  defp paths_dirname(paths), do: MapSet.new(paths, &Path.dirname(&1))
end
