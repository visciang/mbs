defmodule MBS.Cache do
  @moduledoc """
  Artifact Cache
  """

  @spec put(Path.t(), String.t(), String.t(), String.t()) :: :ok
  def put(cache_dir, name, checksum, target) do
    dest_dir = Path.join([cache_dir, name, checksum])
    dest_target = Path.join([dest_dir, Path.basename(target)])
    File.mkdir_p!(dest_dir)
    File.cp!(target, dest_target)
  end

  @spec get(Path.t(), String.t(), String.t(), String.t()) :: {:ok, Path.t()} | :error
  def get(cache_dir, name, checksum, target) do
    target_path = path(cache_dir, name, checksum, target)

    if File.exists?(target_path) do
      {:ok, target_path}
    else
      :error
    end
  end

  @spec hit(Path.t(), String.t(), String.t(), String.t()) :: boolean()
  def hit(cache_dir, name, checksum, target) do
    target_path = path(cache_dir, name, checksum, target)
    File.exists?(target_path)
  end

  @spec path(Path.t(), String.t(), String.t(), String.t()) :: Path.t()
  def path(cache_dir, name, checksum, target) do
    Path.join([cache_dir, name, checksum, Path.basename(target)])
  end
end
