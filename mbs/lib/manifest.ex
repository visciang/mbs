defmodule MBS.Manifest.Data do
  @moduledoc false

  defmodule Job do
    @moduledoc false
    @enforce_keys [:command, :files, :targets]
    defstruct [:command, :files, :targets, :dependencies]
  end

  @enforce_keys [:name, :dir, :job]
  defstruct [:name, :dir, :job]
end

defmodule MBS.Manifest do
  @moduledoc """
  .mbs.json manifest
  """

  alias MBS.Manifest.{Data, Validator}

  @manifest_filename ".mbs.json"

  def find_all do
    "**/#{@manifest_filename}"
    |> Path.wildcard(match_dot: true)
    |> Enum.map(fn manifest_path ->
      Jason.decode!(File.read!(manifest_path))
      |> Map.put("dir", Path.dirname(Path.expand(manifest_path)))
    end)
    |> Validator.validate()
    |> Enum.map(&to_struct/1)
  end

  defp to_struct(manifest_json) do
    dir = Map.get(manifest_json, "dir")
    name = Map.get(manifest_json, "name")
    job = Map.get(manifest_json, "job")
    command = Map.get(job, "command")
    files_ = files(dir, Map.get(job, "files"))
    targets_ = targets(dir, Map.get(job, "targets"))
    dependencies = Map.get(job, "dependencies", [])

    %Data{
      dir: dir,
      name: name,
      job: %Data.Job{
        command: command,
        files: files_,
        targets: targets_,
        dependencies: dependencies
      }
    }
  end

  defp files(dir, file_globs) do
    [@manifest_filename | file_globs]
    |> Enum.flat_map(&Path.wildcard(Path.join(dir, &1), match_dot: true))
    |> Enum.uniq()
  end

  defp targets(dir, targets) do
    targets
    |> Enum.map(&Path.join(dir, &1))
    |> Enum.uniq()
  end
end
