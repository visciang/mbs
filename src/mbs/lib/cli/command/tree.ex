defmodule MBS.CLI.Command.Tree do
  @moduledoc false

  defstruct [:type, :targets]

  @type t :: %__MODULE__{
          type: MBS.Manifest.BuildDeploy.Type.type(),
          targets: [String.t()]
        }
end

defimpl MBS.CLI.Command, for: MBS.CLI.Command.Tree do
  alias MBS.CLI.Command
  alias MBS.{CLI, Config}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Workflow.Job

  @spec run(CLI.Command.Tree.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.Tree{type: type, targets: target_ids}, %Config.Data{} = config, cwd) do
    IO.puts("")

    manifests = BuildDeploy.find_all(type, config, cwd)

    target_ids = if target_ids == [], do: Enum.map(manifests, & &1.id), else: target_ids

    manifests_map =
      manifests
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Map.new(&{&1.id, &1})

    print_tree(target_ids, manifests_map, "")

    :ok
  end

  @spec print_tree([String.t()], %{String.t() => BuildDeploy.Type.t()}, IO.chardata()) :: :ok
  defp print_tree(names, manifests_map, indent) do
    names_length = length(names)

    names
    |> Enum.sort()
    |> Enum.with_index(1)
    |> Enum.each(fn {id, idx} ->
      guide = if idx == names_length, do: "└── ", else: "├── "
      IO.puts(IO.ANSI.format([indent, guide, :bright, id]))

      dependencies = Job.Utils.component_dependencies(manifests_map[id])
      guide = if idx == names_length, do: "    ", else: "│   "

      print_tree(dependencies, manifests_map, [indent | guide])
    end)
  end
end
