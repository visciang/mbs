defmodule MBS do
  @moduledoc """
  Multi Build System
  """

  alias MBS.Config
  alias MBS.Utils
  alias MBS.CLI.{Args, Command, Reporter}

  @spec main([String.t()]) :: :ok
  def main(args) do
    {:ok, reporter} = Reporter.start_link()

    config = Config.load()

    workflow_status =
      args
      |> Args.parse(reporter)
      |> Command.run(config, reporter)
      |> exit_status()

    Reporter.stop(reporter, workflow_status)

    :ok
  end

  defp exit_status(workflow_status) do
    case workflow_status do
      :ok ->
        :ok

      :error ->
        Utils.halt(nil, 1)

      :timeout ->
        Utils.halt(nil, 2)
    end
  end
end
