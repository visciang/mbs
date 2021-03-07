defmodule MBS.Checksum do
  @moduledoc """
  Checksums functions
  """

  def files_checksum(files) do
    files
    |> Enum.sort()
    |> Stream.map(&file_checksum/1)
    |> checksum("")
  end

  def file_checksum(filename) do
    checksum(File.stream!(filename, [], 2048), filename)
  end

  def checksum(data, filename) when is_binary(data) do
    :crypto.hash(:sha256, [filename, data])
    |> Base.encode32(padding: false)
  end

  def checksum(data_chunks, filename) do
    Stream.concat([filename], data_chunks)
    |> Enum.reduce(
      :crypto.hash_init(:sha256),
      fn data_chunk, acc -> :crypto.hash_update(acc, data_chunk) end
    )
    |> :crypto.hash_final()
    |> Base.encode32(padding: false)
  end
end
