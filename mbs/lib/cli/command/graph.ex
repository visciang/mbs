defmodule MBS.CLI.Command.Graph do
  @moduledoc false
  defstruct [:type, :targets, :output_filename]

  @type t :: %__MODULE__{
          type: MBS.Manifest.Type.type(),
          targets: [String.t()],
          output_filename: Path.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Graph do
  alias MBS.CLI.{Command, Reporter, Utils}
  alias MBS.{Config, Const, Manifest, Workflow}

  @spec run(Command.Graph.t(), Config.Data.t(), Reporter.t()) :: :ok | :error
  def run(
        %Command.Graph{type: type, targets: target_ids, output_filename: output_filename},
        %Config.Data{} = config,
        reporter
      ) do
    if dot_command_installed?() do
      File.mkdir_p!(Const.graph_dir())

      Manifest.find_all(type)
      |> Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(config, reporter, fn _, _, _ -> :ok end)
      |> Dask.Dot.export()
      |> Dask.Utils.dot_to_svg(output_filename)

      IO.puts("Produced #{output_filename}")

      :ok
    else
      :error
    end
  end

  defp dot_command_installed? do
    System.cmd("dot", ["-V"], stderr_to_stdout: true)
    true
  rescue
    ErlangError ->
      false
  end
end
