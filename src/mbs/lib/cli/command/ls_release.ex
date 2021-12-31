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

  @spec run(Command.LsRelease.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.LsRelease{verbose: verbose, targets: target_ids}, %Config.Data{}, _cwd) do
    IO.puts("")

    Release.find_all()
    |> Enum.filter(&Utils.filter_manifest_by_id(&1.id, target_ids))
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, verbose))

    :ok
  end

  @spec print_ls(Release.Type.t(), boolean()) :: :ok
  defp print_ls(%Release.Type{} = release, true) do
    IO.puts(IO.ANSI.format([:bright, "#{release.id}", :normal, ":"]))

    if release.metadata do
      IO.puts("  metadata:")
      IO.puts("    #{release.metadata}")
    end

    IO.puts("  components:")

    release.deploy_manifests
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&IO.puts("  - #{&1.id}  (#{&1.checksum})"))

    IO.puts("")
  end

  defp print_ls(%Release.Type{} = release, false) do
    IO.puts(IO.ANSI.format([:bright, "#{release.id}"]))
  end
end
