defimpl MBS.CLI.Command, for: MBS.CLI.Args.Graph do
  alias MBS.CLI.Args
  alias MBS.CLI
  alias MBS.Config
  alias MBS.{Manifest, Workflow}

  def run(%Args.Graph{targets: target_ids, output_svg_file: output_svg_file}, %Config.Data{} = config, reporter) do
    Manifest.find_all()
    |> CLI.Utils.transitive_dependencies_closure(target_ids)
    |> Workflow.workflow(config, reporter, fn _, _, _ -> :ok end)
    |> Dask.Dot.export()
    |> Dask.Utils.dot_to_svg(output_svg_file)

    :ok
  end
end
