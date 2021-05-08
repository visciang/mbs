defmodule MBS do
  @moduledoc false

  alias MBS.{Config, Env, Utils}
  alias MBS.CLI.{Args, Command, Reporter}

  @spec main([String.t()]) :: :ok
  def main(args) do
    args
    |> run()
    |> exit_with()
  end

  @spec run([String.t()], Path.t()) :: Command.on_run()
  def run(args, cwd \\ ".") do
    :ok = Reporter.start_link()

    :ok = Env.validate()
    config = Config.load(cwd)

    workflow_status =
      args
      |> Args.parse()
      |> case do
        :ok -> :ok
        :error -> :error
        command -> Command.run(command, config, cwd)
      end

    Reporter.stop(workflow_status)

    workflow_status
  end

  @spec exit_with(Command.on_run()) :: :ok
  defp exit_with(:ok), do: :ok
  defp exit_with(:error), do: Utils.halt(nil, 1)
  defp exit_with(:timeout), do: Utils.halt(nil, 2)
end
