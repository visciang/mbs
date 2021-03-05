defimpl MBS.CLI.Command, for: MBS.CLI.Args.Run do
  alias MBS.CLI
  alias MBS.CLI.Args
  alias MBS.Config
  alias MBS.{Manifest, Utils, Workflow}

  def run(%Args.Run{targets: target_ids, logs: logs_enabled}, %Config.Data{} = config, reporter) do
    job_on_exit = fn job_id, job_exec_result, elapsed ->
      Workflow.Job.job_fun_on_exit(job_id, job_exec_result, elapsed, reporter)
    end

    dask =
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(config, reporter, &Workflow.Job.job_fun(&1, &2, &3, logs_enabled), job_on_exit)

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
