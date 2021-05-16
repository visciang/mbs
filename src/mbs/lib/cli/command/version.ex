defmodule MBS.CLI.Command.Version do
  @moduledoc false

  defstruct []

  @type t :: %__MODULE__{}
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Version do
  alias MBS.CLI.Command
  alias MBS.Config

  @spec run(Command.Version.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.Version{}, %Config.Data{}, _cwd) do
    IO.puts(System.fetch_env!("MBS_VERSION"))

    :ok
  end
end
