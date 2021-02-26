defmodule MBS.Manifest.Validator do
  @moduledoc """
  Manifest file validator
  """

  alias MBS.Utils

  @name_regex "^[a-zA-Z0-9_:]+$"

  def validate(manifests) do
    validate_schema(manifests)

    components = MapSet.new(manifests, & &1["name"])
    validate_unique_components_name(manifests, components)
    validate_dependencies(manifests, components)

    manifests
  end

  defp validate_schema(manifests) do
    Enum.each(manifests, fn manifest ->
      validate_name(manifest)
      validate_job(manifest)
    end)
  end

  defp validate_name(manifest) do
    if manifest["name"] == nil do
      error_message = IO.ANSI.format([:red, "Missing name field in #{manifest["dir"]}"], true)
      Utils.halt(error_message)
    end

    unless is_binary(manifest["name"]) do
      error_message = IO.ANSI.format([:red, "Bad name type in #{manifest["dir"]}"], true)
      Utils.halt(error_message)
    end

    unless manifest["name"] =~ ~r/#{@name_regex}/ do
      error_message =
        IO.ANSI.format(
          [:red, "Invalid name #{inspect(manifest["name"])} in #{manifest["dir"]} (valid pattern is #{@name_regex})"],
          true
        )

      Utils.halt(error_message)
    end
  end

  defp validate_job(manifest) do
    if manifest["job"] == nil do
      error_message = IO.ANSI.format([:red, "Missing job field in #{manifest["dir"]}"], true)
      Utils.halt(error_message)
    end

    unless is_map(manifest["job"]) do
      error_message = IO.ANSI.format([:red, "Bad job type in #{manifest["dir"]}"], true)
      Utils.halt(error_message)
    end

    validate_list_of_strings(manifest, ["job", "command"])
    validate_list_of_strings(manifest, ["job", "files"])
    validate_list_of_strings(manifest, ["job", "targets"])

    if manifest["job"]["dependencies"] do
      validate_list_of_strings(manifest, ["job", "dependencies"])
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

  defp validate_unique_components_name(manifests, components) do
    if MapSet.size(components) != length(manifests) do
      error_message =
        manifests
        |> Enum.group_by(& &1["name"])
        |> Enum.filter(fn {_name, group} -> length(group) > 1 end)
        |> Enum.map(fn {name, group} ->
          [IO.ANSI.format([:red, "Duplicated name #{inspect(name)} in:\n"], true), Enum.map(group, &"- #{&1["dir"]}\n")]
        end)

      Utils.halt(error_message)
    end
  end

  defp validate_dependencies(manifests, components) do
    manifests
    |> Stream.filter(&(&1["job"]["dependencies"] != nil))
    |> Enum.each(fn manifest ->
      unknown_dependencies = MapSet.difference(MapSet.new(manifest["job"]["dependencies"]), components)

      if MapSet.size(unknown_dependencies) != 0 do
        error_message =
          IO.ANSI.format([:red, "Unknown dependencies #{inspect(unknown_dependencies)} in #{manifest["dir"]}"], true)

        Utils.halt(error_message)
      end
    end)
  end
end
