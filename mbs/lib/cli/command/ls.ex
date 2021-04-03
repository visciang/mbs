defmodule MBS.CLI.Command.Ls do
  @moduledoc false
  defstruct [:type, :verbose, :targets]

  @type t :: %__MODULE__{
          type: MBS.Manifest.Type.type(),
          verbose: boolean(),
          targets: [String.t()]
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Ls do
  alias MBS.CLI.{Command, Utils}
  alias MBS.{Config, Manifest}

  @spec run(Command.Ls.t(), Config.Data.t()) :: :ok
  def run(%Command.Ls{type: type, verbose: verbose, targets: target_ids}, %Config.Data{}) do
    IO.puts("")

    Manifest.find_all(type)
    |> Enum.filter(&Utils.filter_manifest_by_id(&1.id, target_ids))
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, type, verbose))

    :ok
  end

  @spec print_ls(Manifest.Component.t(), Manifest.Type.type(), boolean()) :: :ok
  defp print_ls(%Manifest.Component{} = component, type, true) do
    IO.puts(IO.ANSI.format([:bright, "#{component.id}", :normal, "  (component)", ":"]))
    IO.puts("  dir:")
    IO.puts("    #{component.dir}")
    IO.puts("  timeout:")
    IO.puts("    #{component.timeout}")
    IO.puts("  toolchain:")
    IO.puts("    #{component.toolchain.id}")
    IO.puts("  targets:")

    Enum.each(component.targets, &IO.puts("    - #{target_to_str(&1)}"))

    IO.puts("  files:")

    component.files
    |> Enum.sort()
    |> Enum.each(
      &case type do
        :build -> IO.puts("    - #{&1}")
        :deploy -> IO.puts("    - #{target_to_str(&1)}")
      end
    )

    if component.dependencies != [] do
      IO.puts("  dependencies:")
      Enum.each(component.dependencies, &IO.puts("    - #{&1}"))
    end

    if component.docker_opts != [] do
      IO.puts("  docker_opts:")
      Enum.each(component.docker_opts, &IO.puts("    - #{&1}"))
    end

    IO.puts("")
  end

  defp print_ls(%Manifest.Toolchain{} = toolchain, _type, true) do
    IO.puts(IO.ANSI.format([:bright, "#{toolchain.id}", :normal, "  (toolchain)", ":"]))
    IO.puts("  dir:")
    IO.puts("    #{toolchain.dir}")
    IO.puts("  timeout:")
    IO.puts("    #{toolchain.timeout}")
    IO.puts("  dockerfile:")
    IO.puts("    #{toolchain.dockerfile}")
    IO.puts("  steps:")
    Enum.each(toolchain.steps, &IO.puts("    - #{&1}"))

    if toolchain.destroy_steps != [] do
      IO.puts("  destroy_steps:")
      Enum.each(toolchain.destroy_steps, &IO.puts("    - #{&1}"))
    end

    IO.puts("  files:")
    toolchain.files |> Enum.sort() |> Enum.each(&IO.puts("    - #{&1}"))

    if toolchain.docker_opts != [] do
      IO.puts("  docker_opts:")
      Enum.each(toolchain.docker_opts, &IO.puts("    - #{&1}"))
    end

    IO.puts("")
  end

  defp print_ls(manifest, _type, false) do
    IO.puts(IO.ANSI.format([:bright, manifest.id, :normal, "  (", flavor(manifest), ")"]))
  end

  defp target_to_str(target) do
    case target do
      %Manifest.Target{type: :file, target: target} ->
        target

      %Manifest.Target{type: :docker, target: target} ->
        "docker://#{target}"
    end
  end

  defp flavor(%Manifest.Toolchain{}), do: "toolchain"
  defp flavor(%Manifest.Component{}), do: "component"
end
