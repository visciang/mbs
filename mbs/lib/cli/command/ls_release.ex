defmodule MBS.CLI.Command.LsRelease do
  @moduledoc false
  defstruct [:type, :verbose, :targets]

  @type t :: %__MODULE__{
          verbose: boolean(),
          targets: [String.t()]
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.LsRelease do
  alias MBS.CLI.{Command, Utils}
  alias MBS.Config
  alias MBS.Manifest.Release

  require Logger

  @spec run(Command.LsRelease.t(), Config.Data.t()) :: :ok
  def run(%Command.LsRelease{verbose: verbose, targets: target_ids}, %Config.Data{}) do
    Logger.info("")

    Release.find_all()
    |> Enum.filter(&Utils.filter_manifest_by_id(&1.id, target_ids))
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, verbose))

    :ok
  end

  @spec print_ls(Release.Type.t(), boolean()) :: :ok
  defp print_ls(%Release.Type{} = release, true) do
    Logger.info(IO.ANSI.format([:bright, "#{release.id}", :normal, ":"]))
    Logger.info("  checksum:")
    Logger.info("    #{release.checksum}")

    if release.metadata do
      Logger.info("  metadata:")
      Logger.info("    #{release.metadata}")
    end

    Logger.info("  components:")

    Release.find_all_metadata(release.id)
    |> Enum.sort_by(& &1["id"])
    |> Enum.each(&Logger.info("  - #{&1["id"]}  (#{&1["checksum"]})"))

    Logger.info("")
  end

  defp print_ls(%Release.Type{} = release, false) do
    Logger.info(IO.ANSI.format([:bright, "#{release.id}"]))
  end
end
