defimpl MBS.CLI.Command, for: MBS.CLI.Args.Ls do
  alias MBS.CLI.Args
  alias MBS.Config
  alias MBS.Manifest

  def run(%Args.Ls{verbose: verbose}, %Config.Data{}, _reporter) do
    IO.puts("")

    Manifest.find_all()
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, verbose))

    :ok
  end

  defp print_ls(%Manifest.Component{} = component, true) do
    IO.puts(IO.ANSI.format([:bright, "#{component.id}", :normal, ":"], true))
    IO.puts("  directory:")
    IO.puts("    #{component.dir}")
    IO.puts("  toolchain:")
    IO.puts("    #{component.toolchain.id}")
    IO.puts("  targets:")
    Enum.each(component.targets, &IO.puts("    - #{&1}"))
    IO.puts("  files:")
    Enum.each(component.files, &IO.puts("    - #{&1}"))

    if component.dependencies != [] do
      IO.puts("  dependencies:")
      Enum.each(component.dependencies, &IO.puts("    - #{&1}"))
    end

    IO.puts("")
  end

  defp print_ls(%Manifest.Toolchain{} = toolchain, true) do
    IO.puts(IO.ANSI.format([:bright, "#{toolchain.id}", :normal, ":"], true))
    IO.puts("  directory:")
    IO.puts("    #{toolchain.dir}")
    IO.puts("  dockerfile:")
    IO.puts("    #{toolchain.dockerfile}")
    IO.puts("  steps:")
    Enum.each(toolchain.steps, &IO.puts("    - #{&1}"))
    IO.puts("  files:")
    Enum.each(toolchain.files, &IO.puts("    - #{&1}"))

    IO.puts("")
  end

  defp print_ls(manifest, false) do
    IO.puts(IO.ANSI.format([:bright, manifest.id], true))
  end
end
