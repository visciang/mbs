defmodule MBS do
  @moduledoc """
  a Meta Build System
  """

  alias MBS.{Config, Env, Utils}
  alias MBS.CLI.{Args, Command, Reporter}

  @spec main([String.t()]) :: :ok
  def main(args) do
    :ok = Reporter.start_link()

    :ok = Env.validate()
    config = Config.load()

    workflow_status =
      args
      |> Args.parse()
      |> Command.run(config)

    Reporter.stop(workflow_status)

    exit_with(workflow_status)
  end

  @spec exit_with(:ok | :error | :timeout) :: :ok
  defp exit_with(:ok), do: :ok
  defp exit_with(:error), do: Utils.halt(nil, 1)
  defp exit_with(:timeout), do: Utils.halt(nil, 2)
end
