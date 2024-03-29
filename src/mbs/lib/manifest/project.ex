defmodule MBS.Manifest.Project do
  @moduledoc false

  alias MBS.{Const, Utils}
  alias MBS.Manifest.BuildDeploy

  @spec load(Path.t(), BuildDeploy.Type.type()) :: [Path.t()]
  def load(manifest_path, type) do
    dir = Path.dirname(manifest_path)

    manifest_path
    |> File.read!()
    |> Jason.decode()
    |> case do
      {:ok, conf} ->
        conf

      {:error, reason} ->
        Utils.halt("Error parsing #{manifest_path}\n  #{Jason.DecodeError.message(reason)}")
    end
    |> to_components_dirs(type, dir)
  end

  @spec to_components_dirs(map(), BuildDeploy.Type.type(), Path.t()) :: [Path.t()]
  defp to_components_dirs(manifest_map, type, base_dir) do
    unless is_map(manifest_map) do
      message = "Bad mbs-project.json type"
      Utils.halt(message)
    end

    unless is_list(manifest_map["dirs"]) and Enum.all?(manifest_map["dirs"], &is_binary/1) do
      message = "Bad mbs-project.json dirs type"
      Utils.halt(message)
    end

    Enum.flat_map(manifest_map["dirs"], fn dir ->
      dir = Path.join(base_dir, dir)

      unless File.dir?(dir) do
        message = "Bad mbs-project.json, #{dir} not found"
        Utils.halt(message)
      end

      case type do
        :build ->
          [
            Path.join(dir, Const.manifest_toolchain_filename()),
            Path.join(dir, Const.manifest_build_filename())
          ]

        :deploy ->
          [
            Path.join(dir, Const.manifest_toolchain_filename()),
            Path.join(dir, Const.manifest_deploy_filename())
          ]
      end
      |> Enum.filter(&File.exists?(&1))
    end)
    |> Enum.uniq()
  end
end
