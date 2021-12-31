defmodule MBS.CLI.Command.Outdated do
  @moduledoc false

  defstruct []

  @type t :: %__MODULE__{}
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Outdated do
  alias MBS.CLI.{Command, Reporter}
  alias MBS.Config
  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  require Reporter.Status

  @spec run(Command.Outdated.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.Outdated{}, %Config.Data{} = config, cwd) do
    BuildDeploy.find_all(:build, config, cwd)
    |> filter_outdated(config)
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&Reporter.job_report(&1.id, Reporter.Status.outdated(), &1.checksum, nil))

    :ok
  end

  @spec filter_outdated([BuildDeploy.Type.t()], Config.Data.t()) :: [BuildDeploy.Type.t()]
  defp filter_outdated(components, config) do
    Enum.reduce(components, MapSet.new(), fn
      %BuildDeploy.Toolchain{id: id, checksum: checksum} = toolchain, outdated_set ->
        if Job.Cache.hit_toolchain(config, id, checksum) do
          outdated_set
        else
          MapSet.put(outdated_set, toolchain)
        end

      %BuildDeploy.Component{id: id, checksum: checksum, targets: targets} = component, outdated_set ->
        if Job.Cache.hit_targets(config, id, checksum, targets) do
          outdated_set
        else
          MapSet.put(outdated_set, component)
        end
    end)
  end
end
