defmodule MBS.CLI.Command.Graph do
  @moduledoc false
  defstruct [:targets, :output_svg_file]

  @type t :: %__MODULE__{
          targets: [String.t()],
          output_svg_file: Path.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Graph do
  alias MBS.CLI.{Command, Reporter, Utils}
  alias MBS.{Config, Manifest, Workflow}

  @spec run(Command.Graph.t(), Config.Data.t(), Reporter.t()) :: :error | :ok
  def run(%Command.Graph{targets: target_ids, output_svg_file: output_svg_file}, %Config.Data{} = config, reporter) do
    if dot_command_installed?() do
      Manifest.find_all()
      |> Utils.transitive_dependencies_closure(target_ids)
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
