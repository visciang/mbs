defmodule MBS.Manifest.Release do
  @moduledoc false

  alias MBS.{Const, Utils}
  alias MBS.Manifest.BuildDeploy
  alias MBS.Manifest.Release.Type

  @spec find_all :: [Type.t()]
  def find_all do
    Path.join([Const.releases_dir(), "*", "#{Const.manifest_release_filename()}"])
    |> Path.wildcard(match_dot: true)
    |> Enum.map(&decode/1)
  end

  @spec release_dir(String.t()) :: Path.t()
  def release_dir(release_id) do
    Path.join(Const.releases_dir(), release_id)
  end

  @spec get_release(String.t()) :: Type.t()
  def get_release(release_id) do
    release_dir = release_dir(release_id)
    release_manifest_path = Path.join(release_dir, Const.manifest_release_filename())

    unless File.exists?(release_manifest_path) do
      error_message = "Can't find release #{release_manifest_path}"
      Utils.halt(error_message)
    end

    decode(release_manifest_path)
  end

  @spec write(String.t(), [BuildDeploy.Type.t()], [BuildDeploy.Type.t()], nil | String.t()) :: :ok
  def write(release_id, deploy_manifests, build_manifests, metadata) do
    release_dir = release_dir(release_id)

    release_manifest = %Type{
      id: release_id,
      metadata: metadata,
      deploy_manifests: deploy_manifests,
      build_manifests: build_manifests
    }

    File.write!(
      Path.join(release_dir, Const.manifest_release_filename()),
      :erlang.term_to_binary(release_manifest)
    )
  end

  @spec decode(Path.t()) :: Type.t()
  defp decode(manifest_path) do
    manifest_path
    |> File.read!()
    |> :erlang.binary_to_term()
  end
end
