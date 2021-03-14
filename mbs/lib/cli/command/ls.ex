defmodule MBS.CLI.Command.Ls do
  @moduledoc false
  defstruct [:verbose, :targets]

  @type t :: %__MODULE__{
          verbose: boolean(),
          targets: [String.t()]
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Ls do
  alias MBS.CLI.{Command, Reporter, Utils}
  alias MBS.{Config, Manifest}

  @spec run(Command.Ls.t(), Config.Data.t(), Reporter.t()) :: :ok
  def run(%Command.Ls{verbose: verbose, targets: target_ids}, %Config.Data{}, _reporter) do
    IO.puts("")

    Manifest.find_all()
    |> Enum.filter(&Utils.filter_manifest_by_id(&1.id, target_ids))
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, verbose))

    :ok
  end

  defp print_ls(%Manifest.Component{} = component, true) do
    IO.puts(IO.ANSI.format([:bright, "#{component.id}", :normal, ":"]))
    IO.puts("  dir:")
    IO.puts("    #{component.dir}")
    IO.puts("  timeout:")
    IO.puts("    #{component.timeout}")
    IO.puts("  toolchain:")
    IO.puts("    #{component.toolchain.id}")
    IO.puts("  targets:")

    Enum.each(component.targets, &IO.puts("    - #{target_to_str(&1)}"))

    IO.puts("  files:")
    component.files |> Enum.sort() |> Enum.each(&IO.puts("    - #{&1}"))

    if component.dependencies != [] do
      IO.puts("  dependencies:")
      Enum.each(component.dependencies, &IO.puts("    - #{&1}"))
    end

    IO.puts("")
  end

  defp print_ls(%Manifest.Toolchain{} = toolchain, true) do
    IO.puts(IO.ANSI.format([:bright, "#{toolchain.id}", :normal, ":"]))
    IO.puts("  dir:")
    IO.puts("    #{toolchain.dir}")
    IO.puts("  timeout:")
    IO.puts("    #{toolchain.timeout}")
    IO.puts("  dockerfile:")
    IO.puts("    #{toolchain.dockerfile}")
    IO.puts("  steps:")
    Enum.each(toolchain.steps, &IO.puts("    - #{&1}"))
    IO.puts("  files:")
    toolchain.files |> Enum.sort() |> Enum.each(&IO.puts("    - #{&1}"))

    IO.puts("")
  end

  defp print_ls(manifest, false) do
    extras =
      case manifest do
        %Manifest.Toolchain{} ->
          "toolchain"

        %Manifest.Component{} ->
          "component"
      end

    IO.puts(IO.ANSI.format([:bright, manifest.id, :normal, "  (", extras, ")"]))
  end

  defp target_to_str(target) do
    case target do
      %Manifest.Target{type: :file, target: target} ->
        target

      %Manifest.Target{type: :docker, target: target} ->
        "docker://#{target}"
    end
  end
end
