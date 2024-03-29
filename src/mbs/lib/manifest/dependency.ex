defmodule MBS.Manifest.Dependency do
  @moduledoc false

  alias MBS.Manifest.Dependency.Type

  @spec write(Path.t(), Type.t()) :: :ok
  def write(path, %Type{} = t) do
    File.write!(
      path,
      t |> Map.from_struct() |> Jason.encode!(pretty: true),
      [:utf8]
    )
  end

  @spec load(Path.t()) :: Type.t()
  def load(path) do
    dependency_manifest =
      path
      |> File.read!()
      |> Jason.decode!()

    %Type{
      id: dependency_manifest["id"],
      checksum: dependency_manifest["checksum"]
    }
  end
end
