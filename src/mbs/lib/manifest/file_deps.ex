defmodule MBS.Manifest.FileDeps do
  @moduledoc false

  alias MBS.Const

  # Fast "glob" considering we have negated globs (eg. "!app/**.txt")
  # :path_glob deps is used here to match? a path against a glob expression
  # (at the time of writing :path_glob functionalities are not available
  # neither in the elixir nor in the erlang stdlib)

  @spec wildcard(Path.t(), [String.t()], keyword()) :: [String.t()]
  def wildcard(dir, globs, opts) do
    dir = dir |> Path.absname() |> Path.expand()

    {exclude_globs, include_globs} = Enum.split_with(globs, &String.starts_with?(&1, "!"))

    include_globs =
      include_globs
      |> Enum.map(fn include_glob ->
        Path.join(dir, include_glob)
        |> PathGlob.compile(opts)
      end)

    exclude_globs =
      (exclude_globs ++ mbs_internal_dirs_exclude())
      |> Enum.map(fn exclude_glob ->
        Path.join(dir, String.slice(exclude_glob, 1..-1))
        |> PathGlob.compile(opts)
      end)

    _wildcard(dir, include_globs, exclude_globs, opts)
  end

  @spec _wildcard(Path.t(), [String.t()], [String.t()], keyword()) :: [String.t()]
  defp _wildcard(dir, include_globs, exclude_globs, opts) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn dir_entry ->
      path = Path.join(dir, dir_entry)

      if Enum.any?(exclude_globs, &String.match?(path, &1)) do
        []
      else
        _wildcard_apply(path, include_globs, exclude_globs, opts)
      end
    end)
  end

  @spec _wildcard_apply(Path.t(), [String.t()], [String.t()], keyword()) :: [String.t()]
  defp _wildcard_apply(path, include_globs, exclude_globs, opts) do
    if File.dir?(path) do
      if not opts[:match_dot] and String.starts_with?(Path.basename(path), ".") do
        []
      else
        _wildcard(path, include_globs, exclude_globs, opts)
      end
    else
      if Enum.any?(include_globs, &String.match?(path, &1)) do
        [path]
      else
        []
      end
    end
  end

  @spec mbs_internal_dirs_exclude :: [Path.t()]
  defp mbs_internal_dirs_exclude do
    ["!#{Const.local_dependencies_targets_dir()}"]
  end
end
