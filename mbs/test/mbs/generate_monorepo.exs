out_dir = "sample"
n_components = 100
n_files_per_component = 10
n_dep_per_component = 2
file_size = 20_000

defmodule Utils do
  def rand_file_content(size) do
    size = trunc(size * 3 / 4)
    Base.encode64(:crypto.strong_rand_bytes(size))
  end

  def component_name(idx, n_components) do
    "component_#{String.pad_leading(to_string(idx), n_components, "0")}"
  end
end

File.rm_rf!(out_dir)
File.mkdir!(out_dir)
File.cd!(out_dir)

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

  mbs_manifest = ~s(
    {
      "id": "#{component_name}",
      "component": {
        "toolchain": "catter-toolchain",
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

File.mkdir!("catter-toolchain")
File.cd("catter-toolchain")

mbs_manifest = ~s(
  {
    "id": "catter-toolchain",
    "toolchain": {
      "dockerfile": "Dockerfile",
      "files": [
          "build.sh"
      ],
      "steps": [
        "build"
      ]
    }
  }
)

File.write!(".mbs.json", mbs_manifest)

script = "cat *.txt > ./${MBS_ID}.target"
File.write!("build.sh", script)

dockerfile = ~s(
  FROM alpine:3.12.4
  ADD build.sh /build.sh
  ENTRYPOINT [ "sh", "/build.sh" ]
)
File.write!("Dockerfile", dockerfile)
