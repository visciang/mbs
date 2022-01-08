defmodule MBS.CLI.Command.Ls do
  @moduledoc false

  defstruct [:type, :verbose, :targets]

  @type t :: %__MODULE__{
          type: MBS.Manifest.BuildDeploy.Type.type(),
          verbose: boolean(),
          targets: [String.t()]
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Ls do
  alias MBS.CLI.{Command, Utils}
  alias MBS.Config
  alias MBS.Manifest.BuildDeploy

  @spec run(Command.Ls.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.Ls{type: type, verbose: verbose, targets: target_ids}, %Config.Data{} = config, cwd) do
    IO.puts("")

    BuildDeploy.find_all(type, config, cwd)
    |> Enum.filter(&Utils.filter_manifest_by_id(&1.id, target_ids))
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, verbose))

    :ok
  end

  @spec print_ls(BuildDeploy.Type.t(), boolean()) :: :ok
  defp print_ls(%BuildDeploy.Component{} = component, true) do
    IO.puts(IO.ANSI.format([:bright, component.id, :normal, "  (component)", ":"]))
    IO.puts("  dir:")
    IO.puts("    #{component.dir}")
    IO.puts("  timeout:")
    IO.puts("    #{component.timeout}")
    IO.puts("  toolchain:")
    IO.puts("    #{component.toolchain.id}")

    if component.dependencies != [] do
      IO.puts("  dependencies:")
      Enum.each(component.dependencies, &IO.puts("    - #{&1.id}"))
    end

    if component.docker_opts != %{run: [], shell: []} do
      IO.puts("  docker_opts:")

      Enum.each(component.docker_opts, fn {k, v} ->
        IO.puts("    #{k}:")
        Enum.each(v, &IO.puts("      - #{&1}"))
      end)
    end

    case component.type do
      %BuildDeploy.Component.Build{} ->
        IO.puts("  targets:")
        Enum.each(component.type.targets, &IO.puts("    - #{target_to_str(&1)}"))

        IO.puts("  files:")

        component.type.files
        |> Enum.sort()
        |> Enum.each(&IO.puts("    - #{&1}"))

        if component.type.services != nil do
          IO.puts("  services:")
          IO.puts("    #{component.type.services}")
        end

      %BuildDeploy.Component.Deploy{} ->
        IO.puts("  build_target_dependencies:")
        Enum.each(component.type.build_target_dependencies, &IO.puts("    - #{target_to_str(&1)}"))
    end

    IO.puts("")
  end

  defp print_ls(%BuildDeploy.Toolchain{} = toolchain, true) do
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

    toolchain.files
    |> Enum.sort()
    |> Enum.each(&IO.puts("    - #{&1}"))

    if toolchain.docker_build_opts != [] do
      IO.puts("  docker_build_opts:")
      Enum.each(toolchain.docker_build_opts, &IO.puts("    - #{&1}"))
    end

    IO.puts("")
  end

  defp print_ls(manifest, false) do
    flavor =
      case manifest do
        %BuildDeploy.Toolchain{} -> "toolchain"
        %BuildDeploy.Component{} -> "component"
      end

    IO.puts(IO.ANSI.format([:bright, manifest.id, :normal, "  (", flavor, ")"]))
  end

  defp target_to_str(target) do
    case target do
      %BuildDeploy.Component.Target{type: :file, target: target} ->
        target

      %BuildDeploy.Component.Target{type: :docker, target: target} ->
        "docker://#{target}"
    end
  end
end
