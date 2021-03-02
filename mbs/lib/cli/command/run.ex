defimpl MBS.CLI.Command, for: MBS.CLI.Args.Run do
  alias MBS.CLI.Args
  alias MBS.Config
  alias MBS.{Manifest, Utils, Workflow}

  def run(%Args.Run{}, %Config.Data{} = config, reporter) do
    dask =
      Manifest.find_all()
      |> Workflow.workflow(config, reporter, &Workflow.Job.job_fun/3)

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
