defmodule MBS.Cache do
  @moduledoc """
  Artifact Cache
  """

  def put(cache_directory, name, checksum, target) do
    dest_dir = Path.join([cache_directory, name, checksum])
    dest_target = Path.join([dest_dir, Path.basename(target)])
    File.mkdir_p!(dest_dir)
    File.cp!(target, dest_target)

    :ok
  end

  def get(cache_directory, name, checksum, target) do
    target_path = path(cache_directory, name, checksum, target)

    if File.exists?(target_path) do
      :ok
    else
      :error
    end
  end

  def hit(cache_directory, name, checksum, target) do
    target_path = path(cache_directory, name, checksum, target)
    File.exists?(target_path)
  end

  def path(cache_directory, name, checksum, target) do
    Path.join([cache_directory, name, checksum, Path.basename(target)])
  end
end
