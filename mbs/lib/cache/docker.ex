defmodule MBS.Cache.Docker do
  @moduledoc """
  Artifact Cache for docker
  """

  alias MBS.Docker

  @spec put(String.t(), String.t()) :: :ok
  def put(_checksum, _name) do
    :ok
  end

  @spec get(String.t(), String.t()) :: :ok | :error
  def get(checksum, name) do
    if hit(checksum, name) do
      :ok
    else
      :error
    end
  end

  @spec hit(String.t(), String.t()) :: boolean()
  def hit(checksum, name) do
    Docker.image_exists(name, checksum)
  end

  @spec path(String.t(), String.t()) :: String.t()
  def path(checksum, name) do
    "#{name}:#{checksum}"
  end
end
