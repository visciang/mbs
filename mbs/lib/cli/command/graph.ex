defmodule MBS.CLI.Command.Graph do
  @moduledoc false
  defstruct [:type, :targets, :output_filename]

  @type t :: %__MODULE__{
          type: MBS.Manifest.BuildDeploy.Type.type(),
          targets: [String.t()],
          output_filename: Path.t()
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Graph do
  alias MBS.CLI.{Command, Utils}
  alias MBS.{Config, Const, Workflow}
  alias MBS.Manifest.BuildDeploy

  @spec run(Command.Graph.t(), Config.Data.t()) :: :ok | :error
  def run(%Command.Graph{type: type, targets: target_ids, output_filename: output_filename}, %Config.Data{} = config) do
    if dot_command_installed?() do
      File.mkdir_p!(Const.graph_dir())

      BuildDeploy.find_all(type, config)
      |> Utils.transitive_dependencies_closure(target_ids)
      |> Workflow.workflow(config, &null_fun/2)
      |> Dask.Dot.export()
      |> Dask.Utils.dot_to_svg(output_filename)

      IO.puts("Produced #{output_filename}")

      :ok
    else
      :error
    end
  end

  @spec dot_command_installed? :: boolean()
  defp dot_command_installed? do
    System.cmd("dot", ["-V"], stderr_to_stdout: true)
    true
  rescue
    ErlangError ->
      false
  end

  defp null_fun(_, _) do
    fn _, _ -> :ok end
  end
end
