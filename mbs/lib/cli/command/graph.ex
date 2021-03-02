defimpl MBS.CLI.Command, for: MBS.CLI.Args.Graph do
  alias MBS.CLI.Args
  alias MBS.Config
  alias MBS.{Manifest, Workflow}

  def run(%Args.Graph{png_file: png_file}, %Config.Data{} = config, reporter) do
    Manifest.find_all()
    |> Workflow.workflow(config, reporter, fn _, _, _ -> :ok end)
    |> Dask.Dot.export()
    |> Dask.Utils.dot_to_png(png_file)

    :ok
  end
end
