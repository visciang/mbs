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
  alias MBS.{Config, ReleaseManifest}

  @spec run(Command.LsRelease.t(), Config.Data.t()) :: :ok
  def run(%Command.LsRelease{verbose: verbose, targets: target_ids}, %Config.Data{}) do
    IO.puts("")

    ReleaseManifest.find_all()
    |> Enum.filter(&Utils.filter_manifest_by_id(&1.id, target_ids))
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, verbose))

    :ok
  end

  @spec print_ls(ReleaseManifest.Type.t(), boolean()) :: :ok
  defp print_ls(%ReleaseManifest.Type{} = release, true) do
    IO.puts(IO.ANSI.format([:bright, "#{release.id}", :normal, ":"]))
    IO.puts("  checksum:")
    IO.puts("    #{release.checksum}")

    if release.metadata do
      IO.puts("  metadata:")
      IO.puts("    #{release.metadata}")
    end

    IO.puts("  components:")

    ReleaseManifest.find_all_metadata()
    |> Enum.sort_by(& &1["id"])
    |> Enum.each(&IO.puts("  - #{&1["id"]}  (#{&1["checksum"]})"))

    IO.puts("")
  end

  defp print_ls(%ReleaseManifest.Type{} = release, false) do
    IO.puts(IO.ANSI.format([:bright, "#{release.id}"]))
  end
end
