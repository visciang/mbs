defmodule MBS.ReleaseManifest do
  @moduledoc """
  MBS release manifest functions
  """

  alias MBS.{Checksum, Const, Manifest, Utils}
  alias MBS.ReleaseManifest.Release

  @spec find_all :: [Release.t()]
  def find_all do
    Path.join([Const.releases_dir(), "**", "#{Const.manifest_release_filename()}"])
    |> Path.wildcard(match_dot: true)
    |> Enum.map(&decode/1)
    |> Enum.map(&to_struct/1)
  end

  @spec find_all_metadata :: [map()]
  def find_all_metadata do
    Path.join([Const.releases_dir(), "**", "#{Const.release_metadata_filename()}"])
    |> Path.wildcard(match_dot: true)
    |> Enum.map(&decode/1)
  end

  @spec get_release(String.t()) :: {Release.t(), Path.t()}
  def get_release(release_id) do
    release_dir = Path.join(Const.releases_dir(), release_id)
    release_manifest_path = Path.join(release_dir, Const.manifest_release_filename())

    unless File.exists?(release_manifest_path) do
      error_message = "Can't find release #{release_manifest_path}"
      Utils.halt(error_message)
    end

    release_metadata_map =
      release_manifest_path
      |> File.read!()
      |> Jason.decode!()

    {
      %Release{
        id: Map.fetch!(release_metadata_map, "id"),
        checksum: Map.fetch!(release_metadata_map, "checksum"),
        metadata: Map.fetch!(release_metadata_map, "metadata")
      },
      release_dir
    }
  end

  @spec write_release_manifest([Manifest.Type.t()], String.t(), nil | String.t()) :: :ok
  def write_release_manifest(manifests, release_id, metadata) do
    release_dir = Path.join(Const.releases_dir(), release_id)

    release_manifest = %Release{
      id: release_id,
      checksum: release_checksum(manifests, release_dir),
      metadata: metadata
    }

    File.write!(
      Path.join(release_dir, Const.manifest_release_filename()),
      release_manifest |> Map.from_struct() |> Jason.encode!(pretty: true)
    )

    :ok
  end

  defp release_checksum(manifests, release_dir) do
    manifests
    |> Enum.map(fn %{id: id} ->
      Path.join([release_dir, id, Const.release_metadata_filename()])
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("checksum")
    end)
    |> Enum.join()
    |> Checksum.checksum()
  end

  defp decode(manifest_path) do
    manifest_path
    |> File.read!()
    |> Jason.decode()
    |> case do
      {:ok, conf} ->
        conf

      {:error, reason} ->
        Utils.halt("Error parsing #{manifest_path}\n  #{Jason.DecodeError.message(reason)}")
    end
  end

  defp to_struct(%{"id" => id, "checksum" => checksum, "metadata" => metadata}) do
    %Release{id: id, checksum: checksum, metadata: metadata}
  end
end