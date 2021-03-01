defmodule MBS.Manifest.Validator do
  @moduledoc """
  Manifest file validator
  """

  alias MBS.Utils

  @name_regex "^[a-zA-Z0-9_-]+$"

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

  defp validate_type(%{"dir" => dir, "toolchain" => toolchain}) do
    unless is_map(toolchain) do
      error_message = IO.ANSI.format([:red, "Bad toolchain type in #{dir}"], true)
      Utils.halt(error_message)
    end

    unless is_binary(toolchain["dockerfile"]) do
      error_message = IO.ANSI.format([:red, "Bad dockerfile type in #{dir}"], true)
      Utils.halt(error_message)
    end

    validate_list_of_strings(toolchain, ["files"])
    validate_list_of_strings(toolchain, ["steps"])
  end

  defp validate_type(%{"dir" => dir, "component" => component}) do
    unless is_map(component) do
      error_message = IO.ANSI.format([:red, "Bad component type in #{dir}"], true)
      Utils.halt(error_message)
    end

    validate_list_of_strings(component, ["files"])
    validate_list_of_strings(component, ["targets"])

    if component["dependencies"] do
      validate_list_of_strings(component, ["dependencies"])
    end
  end

  defp validate_list_of_strings(manifest, path) do
    elm = get_in(manifest, path)

    if elm == nil do
      error_message = IO.ANSI.format([:red, "Missing #{inspect(path)} field in #{manifest["dir"]}"], true)
      Utils.halt(error_message)
    end

    unless is_list(elm) and elm != [] and Enum.all?(elm, &is_binary(&1)) do
      error_message = IO.ANSI.format([:red, "Bad #{inspect(path)} type in #{manifest["dir"]}"], true)
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
      |> Stream.filter(&(&1["toolchain"] != nil))
      |> MapSet.new(& &1["id"])

    manifests
    |> Stream.filter(&(&1["component"] != nil))
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
