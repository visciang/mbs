defimpl MBS.CLI.Command, for: MBS.CLI.Args.Graph do
  alias MBS.CLI.Args
  alias MBS.{CLI, Config, Manifest, Workflow}

  def run(%Args.Graph{targets: target_ids, output_svg_file: output_svg_file}, %Config.Data{} = config, reporter) do
    if dot_command_installed?() do
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(config, reporter, fn _, _, _ -> :ok end)
      |> Dask.Dot.export()
      |> Dask.Utils.dot_to_svg(output_svg_file)

      :ok
    else
      :error
    end
  end

  defp dot_command_installed? do
    System.cmd("dot", ["-V"])
    true
  rescue
    ErlangError ->
      false
  end
end
