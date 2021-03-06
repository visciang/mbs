defimpl MBS.CLI.Command, for: MBS.CLI.Args.Tree do
  alias MBS.CLI.Args
  alias MBS.{CLI, Config, Manifest}

  def run(%Args.Tree{targets: target_ids}, %Config.Data{}, _reporter) do
    manifests_map =
      Manifest.find_all()
      |> CLI.Utils.transitive_dependencies_closure(target_ids)
      |> Map.new(&{&1.id, &1})

    IO.puts("")
    print_tree(Map.keys(manifests_map), manifests_map, "")

    :ok
  end

  defp print_tree(names, manifests_map, indent) do
    names
    |> Enum.sort()
    |> Enum.each(fn id ->
      IO.puts(IO.ANSI.format([indent, :bright, id], true))

      dependencies =
        case manifests_map[id] do
          %Manifest.Component{toolchain: toolchain} ->
            [toolchain.id | manifests_map[id].dependencies]

          %Manifest.Toolchain{} ->
            []
        end

      print_tree(dependencies, manifests_map, ["  " | indent])
    end)
  end
end
