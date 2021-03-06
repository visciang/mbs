defimpl MBS.CLI.Command, for: MBS.CLI.Args.Shell do
  alias MBS.CLI.{Args, Reporter}
  alias MBS.{CLI, Config, Manifest, Utils, Workflow}

  def run(%Args.Shell{target: target, docker_cmd: nil}, %Config.Data{} = config, reporter) do
    CLI.Command.run(%Args.Run{targets: [target]}, config, reporter)
  end

  def run(%Args.Shell{target: target, docker_cmd: true}, %Config.Data{} = config, reporter) do
    Reporter.mute(reporter)

    manifests = Manifest.find_all()

    case Enum.find(manifests, &(&1.id == target)) do
      %Manifest.Component{} ->
        :ok

      %Manifest.Toolchain{} ->
        Utils.halt("Bad target, the target should by a component con a toolchain")

      nil ->
        Utils.halt("Unknown target")
    end

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
end
