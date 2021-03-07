defimpl MBS.CLI.Command, for: MBS.CLI.Args.Shell do
  alias MBS.CLI.{Args, Reporter}
  alias MBS.{CLI, Config, Manifest, Utils, Workflow}

  def run(%Args.Shell{target: target, docker_cmd: nil}, %Config.Data{} = config, reporter) do
    manifests = Manifest.find_all()
    target_direct_dependencies = target_component_direct_dependencies(manifests, target)

    CLI.Command.run(%Args.Run{targets: [target_direct_dependencies]}, config, reporter)
  end

  def run(%Args.Shell{target: target, docker_cmd: true}, %Config.Data{} = config, reporter) do
    Reporter.mute(reporter)

    manifests = Manifest.find_all()

    dask =
      manifests
      |> CLI.Utils.transitive_dependencies_closure([target])
      |> Workflow.workflow(
        config,
        reporter,
        &Workflow.Job.shell_fun(&1, &2, &3, target),
        &Workflow.Job.run_fun_on_exit(&1, &2, &3, reporter)
      )

    dask =
      try do
        Dask.async(dask, config.parallelism)
      rescue
        error in [Dask.Error] ->
          Utils.halt(error.message)
      end

    Dask.await(dask)
  end

  defp target_component_direct_dependencies(manifests, id) do
    case Enum.find(manifests, &(&1.id == id)) do
      %Manifest.Component{} = component ->
        [component.toolchain | component.dependencies]

      %Manifest.Toolchain{} ->
        Utils.halt("Bad target, the target should by a component con a toolchain")

      nil ->
        Utils.halt("Unknown target")
    end
  end
end
