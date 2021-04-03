defmodule MBS do
  @moduledoc """
  Meta Build System
  """

  alias MBS.{Config, Env, Utils}
  alias MBS.CLI.{Args, Command, Reporter}

  @spec main([String.t()]) :: :ok
  def main(args) do
    :ok = Reporter.start_link()

    Env.validate!()
    config = Config.load()

    workflow_status =
      args
      |> Args.parse()
      |> Command.run(config)

    Reporter.stop(workflow_status)

    exit_status(workflow_status)
  end

  @spec exit_status(:ok | :error | :timeout) :: :ok
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
