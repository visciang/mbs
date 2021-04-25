defmodule MBS.CLI.Command.Version do
  @moduledoc false
  defstruct []

  @type t :: %__MODULE__{}
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Version do
  alias MBS.CLI.Command
  alias MBS.Config

  require Logger

  @spec run(Command.Version.t(), Config.Data.t()) :: :ok
  def run(%Command.Version{}, %Config.Data{}) do
    Logger.info(System.fetch_env!("MBS_VERSION"))

    :ok
  end
end
