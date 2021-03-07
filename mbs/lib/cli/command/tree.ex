defimpl MBS.CLI.Command, for: MBS.CLI.Args.Tree do
  alias MBS.CLI.Args
  alias MBS.{CLI, Config, Manifest}

  def run(%Args.Tree{targets: target_ids}, %Config.Data{}, _reporter) do
    manifests_map =
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Map.new(&{&1.id, &1})

    IO.puts("")
    print_tree(target_ids, manifests_map, "")

    :ok
  end

  defp print_tree(names, manifests_map, indent) do
    names_length = length(names)

    names
    |> Enum.sort()
    |> Enum.with_index(1)
    |> Enum.each(fn {id, idx} ->
      guide = if idx == names_length, do: "└── ", else: "├── "
      IO.puts(IO.ANSI.format([indent, guide, :bright, id], true))

      dependencies =
        case manifests_map[id] do
          %Manifest.Component{toolchain: toolchain} ->
            [toolchain.id | manifests_map[id].dependencies]

          %Manifest.Toolchain{} ->
            []
        end

      guide = if idx == names_length, do: "    ", else: "│   "
      print_tree(dependencies, manifests_map, [indent | guide])
    end)
  end
end
