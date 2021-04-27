defmodule MBS.CLI.Command.RmRelease do
  @moduledoc false
  defstruct [:target]

  @type t :: %__MODULE__{
          target: String.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.RmRelease do
  alias MBS.CLI.Command
  alias MBS.{Config, Const}

  @spec run(Command.RmRelease.t(), Config.Data.t(), Path.t()) :: :ok
  def run(%Command.RmRelease{target: release_id}, %Config.Data{}, _cwd) do
    Path.join(Const.releases_dir(), release_id)
    |> File.rm_rf!()

    :ok
  end
end
