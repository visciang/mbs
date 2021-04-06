defmodule MBS.ProjectManifest do
  @moduledoc """
  MBS project manifest
  """

  require Logger

  alias MBS.{Const, Manifest, Utils}

  @spec load(Path.t(), Manifest.Type.type()) :: [Path.t()]
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
    |> process(type, dir)
  end

  @spec write([Manifest.Type.t()], String.t()) :: :ok
  def write(manifests, release_id) do
    release_dir = Path.join(Const.releases_dir(), release_id)
    components_id = Enum.map(manifests, & &1.id)

    File.write!(
      Path.join(release_dir, Const.manifest_project_filename()),
      Jason.encode!(%{dirs: components_id}, pretty: true)
    )
  end

  @spec process(map(), Manifest.Type.type(), Path.t()) :: [Path.t()]
  defp process(manifest_map, type, base_dir) do
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
