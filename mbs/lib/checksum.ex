defmodule MBS.Checksum do
  @moduledoc """
  Checksums functions
  """

  @spec files_checksum([Path.t()], Path.t()) :: String.t()
  def files_checksum(files, relative_to_dir) do
    files
    |> Enum.sort()
    |> Stream.map(&file_checksum(&1, relative_to_dir))
    |> checksum()
  end

  @spec checksum(String.t() | Enumerable.t()) :: String.t()
  def checksum(data) when is_binary(data) do
    :crypto.hash(:sha256, [data])
    |> Base.encode32(padding: false)
  end

  def checksum(data_chunks) do
    data_chunks
    |> Enum.reduce(
      :crypto.hash_init(:sha256),
      fn data_chunk, acc -> :crypto.hash_update(acc, data_chunk) end
    )
    |> :crypto.hash_final()
    |> Base.encode32(padding: false)
  end

  @spec file_checksum(Path.t(), Path.t()) :: String.t()
  defp file_checksum(filename, relative_to_dir) do
    relative_to_dir_filename = Path.relative_to(filename, relative_to_dir)
    checksum(Stream.concat([relative_to_dir_filename], File.stream!(filename, [], 2048)))
  end
end
