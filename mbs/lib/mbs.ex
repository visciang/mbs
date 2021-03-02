defmodule MBS do
  @moduledoc """
  Multi Build System
  """

  alias MBS.Utils
  alias MBS.CLI.{Args, Command, Reporter}

  def main(args) do
    config = MBS.Config.load()

    {:ok, reporter} = Reporter.start_link()

    workflow_status =
      args
      |> Args.parse()
      |> Command.run(config, reporter)
      |> exit_status()

    Reporter.stop(reporter, workflow_status)
  end

  defp exit_status(workflow_status) do
    case workflow_status do
      :ok -> workflow_status
      :error -> Utils.halt(nil, 1)
      :timeout -> Utils.halt(nil, 2)
    end
  end
end
