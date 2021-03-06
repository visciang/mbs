defimpl MBS.CLI.Command, for: MBS.CLI.Args.Run do
  alias MBS.CLI.Args
  alias MBS.{CLI, Config, Manifest, Utils, Workflow}

  def run(%Args.Run{targets: target_ids, logs: logs_enabled}, %Config.Data{} = config, reporter) do
    dask =
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(
        config,
        reporter,
        &Workflow.Job.run_fun(&1, &2, &3, logs_enabled),
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
