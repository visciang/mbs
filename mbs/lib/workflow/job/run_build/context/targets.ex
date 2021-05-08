defmodule MBS.Workflow.Job.RunBuild.Context.Targets do
  @moduledoc false

  alias MBS.Docker
  alias MBS.Manifest.BuildDeploy
  alias MBS.Utils

  @spec get(BuildDeploy.Component.t(), String.t(), boolean()) :: {:ok, Path.t()} | {:error, String.t()}
  def get(%BuildDeploy.Component{id: id, targets: targets}, checksum, true) do
    temp_dir = Utils.mktemp()

    _get(targets, checksum, &(Docker.container_get(id, &1, temp_dir, id) != :ok))
    |> case do
      {:ok, targets} ->
        targets = Enum.map(targets, &put_in(&1.target, Path.join(temp_dir, Path.basename(&1.target))))
        {:ok, targets}

      error ->
        error
    end
  end

  def get(%BuildDeploy.Component{targets: targets}, checksum, false) do
    _get(targets, checksum, &(not File.exists?(&1)))
  end

  @spec _get([BuildDeploy.Target.t()], String.t(), (Path.t() -> boolean())) :: {:ok, Path.t()} | {:error, String.t()}
  defp _get(targets, checksum, copy_fun) do
    missing_docker_targets =
      targets
      |> filter_targets(:docker)
      |> Enum.filter(&(not Docker.image_exists(&1, checksum)))

    missing_file_targets =
      targets
      |> filter_targets(:file)
      |> Enum.filter(copy_fun)

    missing_targets = missing_docker_targets ++ missing_file_targets

    if length(missing_targets) != 0 do
      {:error, "Missing targets #{inspect(missing_targets)}"}
    else
      {:ok, targets}
    end
  end

  @spec filter_targets([BuildDeploy.Target.t()], BuildDeploy.Target.type()) :: [Path.t()]
  defp filter_targets(targets, type) do
    targets
    |> Enum.filter(&match?(%BuildDeploy.Target{type: ^type}, &1))
    |> Enum.map(& &1.target)
  end
end
