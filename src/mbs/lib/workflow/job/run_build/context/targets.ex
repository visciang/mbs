defmodule MBS.Workflow.Job.RunBuild.Context.Targets do
  @moduledoc false

  alias MBS.CLI.Reporter
  alias MBS.Docker
  alias MBS.Manifest.BuildDeploy
  alias MBS.Utils

  require Reporter.Status

  @spec get(BuildDeploy.Component.t(), String.t(), boolean()) :: {:ok, Path.t()} | {:error, String.t()}
  def get(%BuildDeploy.Component{id: id, type: %BuildDeploy.Component.Build{targets: targets}}, checksum, true) do
    temp_dir = Utils.mktemp()

    case _get(targets, id, checksum, &(Docker.container_get(id, &1, temp_dir, id) != :ok)) do
      {:ok, targets} ->
        targets = Enum.map(targets, &put_in(&1.target, Path.join(temp_dir, Path.basename(&1.target))))
        {:ok, targets}

      error ->
        error
    end
  end

  def get(%BuildDeploy.Component{id: id, type: %BuildDeploy.Component.Build{targets: targets}}, checksum, false) do
    _get(targets, id, checksum, &(not File.exists?(&1)))
  end

  @spec _get([BuildDeploy.Component.Target.t()], String.t(), String.t(), (Path.t() -> boolean())) ::
          {:ok, Path.t()} | {:error, String.t()}
  defp _get(targets, id, checksum, copy_fun) do
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
      Enum.each(targets, &Reporter.job_report(id, Reporter.Status.log(), "Get target: #{inspect(&1)}", nil))

      {:ok, targets}
    end
  end

  @spec filter_targets([BuildDeploy.Component.Target.t()], BuildDeploy.Component.Target.type()) :: [Path.t()]
  defp filter_targets(targets, type) do
    targets
    |> Enum.filter(&match?(%BuildDeploy.Component.Target{type: ^type}, &1))
    |> Enum.map(& &1.target)
  end
end
