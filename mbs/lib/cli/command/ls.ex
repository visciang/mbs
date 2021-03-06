defimpl MBS.CLI.Command, for: MBS.CLI.Args.Ls do
  alias MBS.CLI.Args
  alias MBS.CLI.Utils
  alias MBS.Config
  alias MBS.Manifest

  def run(%Args.Ls{verbose: verbose, targets: target_ids}, %Config.Data{}, _reporter) do
    IO.puts("")

    Manifest.find_all()
    |> Enum.filter(&Utils.filter_manifest_by_id(&1.id, target_ids))
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, verbose))

    :ok
  end

  defp print_ls(%Manifest.Component{} = component, true) do
    IO.puts(IO.ANSI.format([:bright, "#{component.id}", :normal, ":"], true))
    IO.puts("  directory:")
    IO.puts("    #{component.dir}")
    IO.puts("  timeout:")
    IO.puts("    #{component.timeout}")
    IO.puts("  toolchain:")
    IO.puts("    #{component.toolchain.id}")
    IO.puts("  targets:")

    Enum.each(component.targets, fn
      %Manifest.Target{type: "file", target: target} ->
        IO.puts("    - #{target}")

      %Manifest.Target{type: "docker", target: target} ->
        IO.puts("    - docker://#{target}")
    end)

    IO.puts("  files:")
    component.files |> Enum.sort() |> Enum.each(&IO.puts("    - #{&1}"))

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
    IO.puts(IO.ANSI.format([:bright, manifest.id], true))
  end
end
