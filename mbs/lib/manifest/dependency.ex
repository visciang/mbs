defmodule MBS.Manifest.Dependency do
  @moduledoc """
  MBS dependency manifest functions
  """

  alias MBS.Manifest.Dependency.Type

  @spec write(Path.t(), Type.t()) :: :ok
  def write(path, %Type{} = t) do
    File.write!(
      path,
      t |> Map.from_struct() |> Jason.encode!(pretty: true)
    )
  end

  @spec load(Path.t()) :: Type.t()
  def load(path) do
    dependency_manifest_map =
      path
      |> File.read!()
      |> Jason.decode!()

    %Type{
      id: dependency_manifest_map["id"],
      checksum: dependency_manifest_map["checksum"]
    }
  end
end
