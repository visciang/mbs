defmodule Dask.Utils do
  @moduledoc """
  Dask utilities
  """

  @minute 60
  @hour @minute * 60
  @day @hour * 24
  @week @day * 7
  @divisor [@week, @day, @hour, @minute, 1]

  @doc """
  Seconds duration to compound representation

    ex> Dask.Utils.seconds_to_compound_duration(12034)
    "3 hr, 20 min, 34 sec"
  """
  @spec seconds_to_compound_duration(number()) :: String.t()
  def seconds_to_compound_duration(sec, precision \\ 3) do
    sec_int = trunc(sec)
    sec_decimals = (sec - sec_int) |> to_string() |> String.slice(2, precision)

    {_, [s, m, h, d, w]} =
      Enum.reduce(@divisor, {sec_int, []}, fn divisor, {n, acc} ->
        {rem(n, divisor), [div(n, divisor) | acc]}
      end)

    ["#{w} wk", "#{d} d", "#{h} hr", "#{m} min", "#{trunc(s)}.#{sec_decimals} sec"]
    |> Enum.reject(&String.starts_with?(&1, "0 "))
    |> Enum.join(", ")
    |> case do
      "" -> "0 sec"
      s -> s
    end
  end

  # coveralls-ignore-start

  @doc """
  Convert a workflow dot graph to png.
  It uses the `dot` program, so it should be installed and available.
  """
  @spec dot_to_png(iodata(), Path.t()) :: :ok
  def dot_to_png(dot, out_file) do
    dot_tmp_file = "#{Path.rootname(out_file)}.dot"
    File.write!(dot_tmp_file, dot)
    {_, 0} = System.cmd("dot", ["-Tpng", dot_tmp_file], into: File.stream!(out_file))
    File.rm!(dot_tmp_file)

    :ok
  end

  # coveralls-ignore-end
end
