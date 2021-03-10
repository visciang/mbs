defmodule MBS.Manifest.Validator do
  @moduledoc """
  Manifest file validator
  """

  alias MBS.Utils

  @name_regex "^[a-zA-Z0-9_-]+$"

  @spec validate([MBS.Manifest.t()]) :: [MBS.Manifest.t()]
  def validate(manifests) do
    validate_schema(manifests)

    ids = MapSet.new(manifests, & &1["id"])
    validate_unique_id(manifests, ids)
    validate_components(manifests, ids)

    manifests
  end

  defp validate_schema(manifests) do
    Enum.each(manifests, fn manifest ->
      validate_id(manifest)
      validate_timeout(manifest)
      validate_type(manifest)
    end)
  end

  defp validate_id(%{"id" => id, "dir" => dir}) do
    if id == nil do
      error_message = IO.ANSI.format([:red, "Missing id field in #{dir}"], true)
      Utils.halt(error_message)
    end

    unless is_binary(id) do
      error_message = IO.ANSI.format([:red, "Bad id type in #{dir}"], true)
      Utils.halt(error_message)
    end

    unless id =~ ~r/#{@name_regex}/ do
      error_message =
        IO.ANSI.format(
          [:red, "Invalid id #{inspect(id)} in #{dir} (valid pattern is #{@name_regex})"],
          true
        )

      Utils.halt(error_message)
    end
  end

  defp validate_timeout(%{"timeout" => timeout, "dir" => dir}) do
    unless timeout == :infinity or (is_integer(timeout) and timeout > 0) do
      error_message = IO.ANSI.format([:red, "Invalid timeout field in #{dir}"], true)
      Utils.halt(error_message)
    end
  end

  defp validate_timeout(_), do: :ok

  defp validate_type(%{"dir" => dir, "toolchain" => toolchain}) do
    unless is_map(toolchain) do
      error_message = IO.ANSI.format([:red, "Bad toolchain type in #{dir}"], true)
      Utils.halt(error_message)
    end

    unless is_binary(toolchain["dockerfile"]) do
      error_message = IO.ANSI.format([:red, "Bad dockerfile type in #{dir}"], true)
      Utils.halt(error_message)
    end

    validate_list_of_strings(toolchain, ["files"], dir)
    validate_list_of_strings(toolchain, ["steps"], dir)
  end

  defp validate_type(%{"dir" => dir, "component" => component}) do
    unless is_map(component) do
      error_message = IO.ANSI.format([:red, "Bad component type in #{dir}"], true)
      Utils.halt(error_message)
    end

    unless is_binary(component["toolchain"]) do
      error_message = IO.ANSI.format([:red, "Bad toolchain type in #{dir}"], true)
      Utils.halt(error_message)
    end

    if component["toolchain_opts"] != nil do
      validate_list_of_strings(component, ["toolchain_opts"], dir)
    end

    validate_list_of_strings(component, ["files"], dir)
    validate_list_of_strings(component, ["targets"], dir)

    if component["dependencies"] do
      validate_list_of_strings(component, ["dependencies"], dir)
    end
  end

  defp validate_list_of_strings(manifest, path, manifest_dir) do
    elm = get_in(manifest, path)

    if elm == nil do
      error_message = IO.ANSI.format([:red, "Missing #{inspect(path)} field in #{manifest_dir}"], true)
      Utils.halt(error_message)
    end

    unless is_list(elm) and Enum.all?(elm, &is_binary(&1)) do
      error_message = IO.ANSI.format([:red, "Bad #{inspect(path)} type in #{manifest_dir}"], true)
      Utils.halt(error_message)
    end
  end

  defp validate_unique_id(manifests, ids) do
    if MapSet.size(ids) != length(manifests) do
      error_message =
        manifests
        |> Enum.group_by(& &1["id"])
        |> Enum.filter(fn {_name, group} -> length(group) > 1 end)
        |> Enum.map(fn {id, group} ->
          [IO.ANSI.format([:red, "Duplicated id #{inspect(id)} in:\n"], true), Enum.map(group, &"- #{&1["dir"]}\n")]
        end)

      Utils.halt(error_message)
    end
  end

  defp validate_components(manifests, ids) do
    toolchains_ids =
      manifests
      |> Enum.filter(&(&1["toolchain"] != nil))
      |> MapSet.new(& &1["id"])

    manifests
    |> Enum.filter(&(&1["component"] != nil))
    |> Enum.each(fn %{"dir" => dir, "component" => component} ->
      unknown_dependencies = MapSet.difference(MapSet.new(component["dependencies"] || []), ids)

      unless MapSet.size(unknown_dependencies) == 0 do
        Utils.halt(IO.ANSI.format([:red, "Unknown dependencies #{inspect(unknown_dependencies)} in #{dir}"], true))
      end

      unless MapSet.member?(toolchains_ids, component["toolchain"]) do
        Utils.halt(IO.ANSI.format([:red, "Unknown toolchain #{inspect(component["toolchain"])} in #{dir}"], true))
      end
    end)
  end
end
