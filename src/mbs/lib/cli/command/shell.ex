defmodule MBS.CLI.Command.Shell do
  @moduledoc false

  defstruct [:target, :docker_cmd]

  @type t :: %__MODULE__{
          target: String.t(),
          docker_cmd: nil | String.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Shell do
  alias MBS.CLI.{Command, Reporter}
  alias MBS.{CLI, Config, Utils}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Toolchain

  @spec run(Command.Shell.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.Shell{target: target, docker_cmd: nil}, %Config.Data{} = config, cwd) do
    manifests = BuildDeploy.find_all(:build, config, cwd)
    target_direct_dependencies = target_component_direct_dependencies(manifests, target)

    build_direct_deps = %Command.RunBuild{targets: target_direct_dependencies, force: false, sandbox: true}
    get_component_deps_only = %Command.RunBuild{targets: [target], force: false, sandbox: false, get_deps_only: true}

    with :ok <- CLI.Command.run(build_direct_deps, config, cwd),
         :ok <- CLI.Command.run(get_component_deps_only, config, cwd) do
      :ok
    else
      err -> err
    end
  end

  def run(%Command.Shell{target: shell_target, docker_cmd: true}, %Config.Data{} = config, cwd) do
    Reporter.mute(true)

    component =
      BuildDeploy.find_all(:build, config, cwd)
      |> Enum.find(&(&1.id == shell_target))

    Toolchain.Shell.cmd(config, component)
    |> IO.puts()

    :ok
  end

  @spec target_component_direct_dependencies([BuildDeploy.Type.t()], String.t()) :: [String.t()]
  defp target_component_direct_dependencies(manifests, id) do
    case Enum.find(manifests, &(&1.id == id)) do
      %BuildDeploy.Component{} = component ->
        BuildDeploy.component_dependencies_ids(component)

      %BuildDeploy.Toolchain{} ->
        Utils.halt("Bad target, the target should be a component not a toolchain")

      nil ->
        Utils.halt("Unknown target")
    end
  end
end
