defmodule MBS.Workflow.Job.RunBuild.Context.Files do
  @moduledoc false

  alias MBS.Docker
  alias MBS.Manifest.BuildDeploy
  alias MBS.Utils

  @spec put(BuildDeploy.Component.t(), boolean()) :: :ok | {:error, term()}
  def put(_component, false = _sandboxed), do: :ok

  def put(%BuildDeploy.Component{id: id, dependencies: dependencies} = component, true = _sandboxed) do
    temp_dir = Utils.mktemp()

    files =
      [component | dependencies]
      |> Enum.flat_map(fn %BuildDeploy.Component{type: %BuildDeploy.Component.Build{files: files}} -> files end)
      |> MapSet.new()

    files
    |> paths_dirname()
    |> Enum.each(&File.mkdir_p!(Path.join(temp_dir, &1)))

    files
    |> Enum.each(&File.ln_s!(&1, Path.join(temp_dir, &1)))

    Docker.container_dput(id, temp_dir, "/", id)
  end

  @spec paths_dirname(MapSet.t(Path.t())) :: MapSet.t(Path.t())
  defp paths_dirname(paths), do: MapSet.new(paths, &Path.dirname(&1))
end
