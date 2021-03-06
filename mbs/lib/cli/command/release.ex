defimpl MBS.CLI.Command, for: MBS.CLI.Args.Release do
  alias MBS.CLI
  alias MBS.CLI.Args
  alias MBS.Config
  alias MBS.{Manifest, Utils, Workflow}

  def run(%Args.Release{targets: target_ids, output_dir: output_dir}, %Config.Data{} = config, reporter) do
    run_on_exit = fn job_id, job_exec_result, elapsed ->
      Workflow.Job.run_fun_on_exit(job_id, job_exec_result, elapsed, reporter)
    end

    dask =
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(config, reporter, &Workflow.Job.release_fun(&1, &2, &3, output_dir), run_on_exit)

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
