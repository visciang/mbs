defmodule MBS.Checksum do
  @moduledoc """
  Checksums functions
  """

  def files_checksum(files) do
    files
    |> Stream.map(&file_checksum/1)
    |> checksum()
  end

  def file_checksum(filename) do
    filename
    |> File.stream!([], 2048)
    |> checksum()
  end

  def checksum(data) when is_binary(data) do
    :crypto.hash(:sha256, [data])
    |> Base.url_encode64(padding: false)
  end

  def checksum(data_chunks) do
    data_chunks
    |> Enum.reduce(
      :crypto.hash_init(:sha256),
      fn data_chunk, acc -> :crypto.hash_update(acc, data_chunk) end
    )
    |> :crypto.hash_final()
    |> Base.url_encode64(padding: false)
  end
end
