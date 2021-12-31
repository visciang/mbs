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

  @spec run(CLI.Command.Tree.t(), Config.Data.t(), Path.t()) :: Command.on_run()
  def run(%Command.Tree{type: type, targets: target_ids}, %Config.Data{} = config, cwd) do
    IO.puts("")

    manifests =
      BuildDeploy.find_all(type, config, cwd)
      |> Enum.filter(&CLI.Utils.filter_manifest_by_id(&1.id, target_ids))

    print_tree(manifests, "")

    :ok
  end

  @spec print_tree([BuildDeploy.Type.t()], IO.chardata()) :: :ok
  defp print_tree(manifests, indent) do
    manifests_length = length(manifests)

    manifests
    |> Enum.sort_by(& &1.id)
    |> Enum.with_index(1)
    |> Enum.each(fn {manifest, idx} ->
      guide = if idx == manifests_length, do: ["└── "], else: ["├── "]
      IO.puts(IO.ANSI.format([indent, guide, :bright, manifest.id]))

      guide = if idx == manifests_length, do: ["    "], else: ["│   "]
      print_tree(deps(manifest), [indent | guide])
    end)
  end

  @spec deps(BuildDeploy.Type.t()) :: [BuildDeploy.Type.t()]
  defp deps(%BuildDeploy.Toolchain{}), do: []
  defp deps(%BuildDeploy.Component{toolchain: toolchain, dependencies: dependencies}), do: [toolchain | dependencies]
end
