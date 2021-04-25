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

  require Logger

  @spec run(Command.Ls.t(), Config.Data.t()) :: :ok
  def run(%Command.Ls{type: type, verbose: verbose, targets: target_ids}, %Config.Data{} = config) do
    Logger.info("")

    BuildDeploy.find_all(type, config)
    |> Enum.filter(&Utils.filter_manifest_by_id(&1.id, target_ids))
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&print_ls(&1, type, verbose))

    :ok
  end

  @spec print_ls(BuildDeploy.Component.t(), BuildDeploy.Type.type(), boolean()) :: :ok
  defp print_ls(%BuildDeploy.Component{} = component, type, true) do
    Logger.info(IO.ANSI.format([:bright, "#{component.id}", :normal, "  (component)", ":"]))
    Logger.info("  dir:")
    Logger.info("    #{component.dir}")
    Logger.info("  timeout:")
    Logger.info("    #{component.timeout}")
    Logger.info("  toolchain:")
    Logger.info("    #{component.toolchain.id}")
    Logger.info("  targets:")

    Enum.each(component.targets, &Logger.info("    - #{target_to_str(&1)}"))

    Logger.info("  files:")

    component.files
    |> Enum.sort()
    |> Enum.each(
      &case type do
        :build -> Logger.info("    - #{&1}")
        :deploy -> Logger.info("    - #{target_to_str(&1)}")
      end
    )

    if component.dependencies != [] do
      Logger.info("  dependencies:")
      Enum.each(component.dependencies, &Logger.info("    - #{&1}"))
    end

    if component.services != nil do
      Logger.info("  services:")
      Logger.info("    #{component.services}")
    end

    if component.docker_opts != [] do
      Logger.info("  docker_opts:")
      Enum.each(component.docker_opts, &Logger.info("    - #{&1}"))
    end

    Logger.info("")
  end

  defp print_ls(%BuildDeploy.Toolchain{} = toolchain, _type, true) do
    Logger.info(IO.ANSI.format([:bright, "#{toolchain.id}", :normal, "  (toolchain)", ":"]))
    Logger.info("  dir:")
    Logger.info("    #{toolchain.dir}")
    Logger.info("  timeout:")
    Logger.info("    #{toolchain.timeout}")
    Logger.info("  dockerfile:")
    Logger.info("    #{toolchain.dockerfile}")
    Logger.info("  steps:")
    Enum.each(toolchain.steps, &Logger.info("    - #{&1}"))

    if toolchain.deps_change_step != nil do
      Logger.info("  deps_change_step:")
      Logger.info("    #{toolchain.deps_change_step}")
    end

    if toolchain.destroy_steps != [] do
      Logger.info("  destroy_steps:")
      Enum.each(toolchain.destroy_steps, &Logger.info("    - #{&1}"))
    end

    Logger.info("  files:")
    toolchain.files |> Enum.sort() |> Enum.each(&Logger.info("    - #{&1}"))

    if toolchain.docker_opts != [] do
      Logger.info("  docker_opts:")
      Enum.each(toolchain.docker_opts, &Logger.info("    - #{&1}"))
    end

    Logger.info("")
  end

  defp print_ls(manifest, _type, false) do
    Logger.info(IO.ANSI.format([:bright, manifest.id, :normal, "  (", flavor(manifest), ")"]))
  end

  defp target_to_str(target) do
    case target do
      %BuildDeploy.Target{type: :file, target: target} ->
        target

      %BuildDeploy.Target{type: :docker, target: target} ->
        "docker://#{target}"
    end
  end

  defp flavor(%BuildDeploy.Toolchain{}), do: "toolchain"
  defp flavor(%BuildDeploy.Component{}), do: "component"
end
