defmodule MBS.Utils do
  @moduledoc false

  @dialyzer {:nowarn_function, halt: 1}

  @spec halt(nil | String.t(), non_neg_integer()) :: no_return()
  def halt(message, exit_status \\ 1) do
    if message != nil and message != "" do
      IO.puts(:stderr, IO.ANSI.format([:red, message]))
    end

    System.halt(exit_status)
  end

  @spec merge_maps(nonempty_list(map())) :: map()
  def merge_maps(maps) do
    Enum.reduce(maps, fn map, map_merge -> Map.merge(map_merge, map) end)
  end

  @spec union_mapsets(nonempty_list(MapSet.t())) :: MapSet.t()
  def union_mapsets(mapsets) do
    Enum.reduce(mapsets, fn mapset, mapsets_union -> MapSet.union(mapsets_union, mapset) end)
  end

  @spec gunzip(Path.t(), Path.t()) :: :ok
  def gunzip(src, dest) do
    src
    |> File.stream!([:compressed], 2048)
    |> Stream.into(File.stream!(dest, [], 2048))
    |> Stream.run()
  end

  @spec mktemp :: String.t()
  def mktemp do
    temp_dir = Path.join(System.tmp_dir!(), inspect(make_ref()))
    File.mkdir!(temp_dir)
    temp_dir
  end
end
