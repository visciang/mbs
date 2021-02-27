n_components = 100
n_files_per_component = 10
n_dep_per_component = 3
file_size = 2_000

defmodule Utils do
  def rand_file_content(len, chars \\ "abcdefghijklmnopqrstuvwxyz") do
    char_count = String.length(chars)

    1..len
    |> Enum.map(fn _ ->
      pos = :rand.uniform(char_count) - 1
      String.at(chars, pos)
    end)
  end

  def component_name(idx, n_components) do
    "component_#{String.pad_leading(to_string(idx), n_components, "0")}"
  end
end

"component_*"
|> Path.wildcard()
|> Enum.each(&File.rm_rf!/1)

component_ids_max_len = String.length(to_string(n_components))

1..n_components
|> Enum.map(&Utils.component_name(&1, component_ids_max_len))
|> Enum.with_index(1)
|> Enum.each(fn {component_name, component_idx} ->
  files = 1..n_files_per_component |> Enum.map(&"file_#{component_idx}_#{&1}.txt")

  File.mkdir!(component_name)

  Enum.each(files, fn file ->
    path = Path.join(component_name, file)
    File.write!(path, Utils.rand_file_content(file_size))
  end)

  component_deps =
    1..n_dep_per_component
    |> Enum.map(fn _ -> Utils.component_name(:rand.uniform(component_idx), component_ids_max_len) end)
    |> Enum.uniq()
    |> List.delete(component_name)

  component_deps = ["toolchains:catter" | component_deps]

  mbs_manifest = ~s(
    {
      "name": "#{component_name}",
      "job": {
          "command": ["$MBS_DEPS_TOOLCHAINS_CATTER/catter.sh", "#{component_name}.target"],
          "files": [
              "*.txt"
          ],
          "targets": [
              "#{component_name}.target"
          ],
          "dependencies": #{inspect(component_deps)}
      }
    }
  )

  manifest_path = Path.join(component_name, ".mbs.json")
  File.write!(manifest_path, mbs_manifest)
end)
