defmodule MBS.Manifest.Validator do
  @moduledoc """
  Manifest file validator
  """

  alias MBS.Utils

  @name_regex "^[a-zA-Z0-9_-]+$"

  @spec validate([MBS.Manifest.Type.t()]) :: [MBS.Manifest.Type.t()]
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
      message = error_message(dir, "Missing id field")
      Utils.halt(message)
    end

    unless is_binary(id) do
      message = error_message(dir, "Bad id type")
      Utils.halt(message)
    end

    unless id =~ ~r/#{@name_regex}/ do
      message = error_message(dir, "Invalid id #{inspect(id)} (valid pattern is #{@name_regex})")

      Utils.halt(message)
    end
  end

  defp validate_timeout(%{"timeout" => timeout, "dir" => dir}) do
    unless timeout == :infinity or (is_integer(timeout) and timeout > 0) do
      message = error_message(dir, "Invalid timeout field")
      Utils.halt(message)
    end
  end

  defp validate_timeout(_), do: :ok

  defp validate_type(%{"dir" => dir, "toolchain" => toolchain}) do
    unless is_map(toolchain) do
      message = error_message(dir, "Bad toolchain type")
      Utils.halt(message)
    end

    unless is_binary(toolchain["dockerfile"]) do
      message = error_message(dir, "Bad dockerfile type")
      Utils.halt(message)
    end

    validate_list_of_strings(toolchain, ["files"], dir)
    validate_list_of_strings(toolchain, ["steps"], dir)
  end

  defp validate_type(%{"dir" => dir, "component" => component}) do
    unless is_map(component) do
      message = error_message(dir, "Bad component type")
      Utils.halt(message)
    end

    unless is_binary(component["toolchain"]) do
      message = error_message(dir, "Bad toolchain type")
      Utils.halt(message)
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

  defp validate_list_of_strings(manifest, path, dir) do
    elm = get_in(manifest, path)

    if elm == nil do
      message = error_message(dir, "Missing #{inspect(path)} field")
      Utils.halt(message)
    end

    unless is_list(elm) and Enum.all?(elm, &is_binary(&1)) do
      message = error_message(dir, "Bad #{inspect(path)} type")
      Utils.halt(message)
    end
  end

  defp validate_unique_id(manifests, ids) do
    if MapSet.size(ids) != length(manifests) do
      message =
        manifests
        |> Enum.group_by(& &1["id"])
        |> Enum.filter(fn {_name, group} -> length(group) > 1 end)
        |> Enum.map(fn {id, group} ->
          [IO.ANSI.format([:red, "Duplicated id #{inspect(id)} in:\n"]), Enum.map(group, &"- #{&1["dir"]}\n")]
        end)

      Utils.halt(message)
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
        message = error_message(dir, "Unknown dependencies #{inspect(unknown_dependencies)}")
        Utils.halt(message)
      end

      unless MapSet.member?(toolchains_ids, component["toolchain"]) do
        message = error_message(dir, "Unknown build.toolchain #{inspect(component["toolchain"])}")
        Utils.halt(message)
      end
    end)
  end

  defp error_message(dir, error_message) do
    IO.ANSI.format([:red, "Error in #{Path.join(dir, ".mbs.json")}\n#{error_message}"])
  end
end
