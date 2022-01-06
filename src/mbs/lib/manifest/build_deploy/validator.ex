defmodule MBS.Manifest.BuildDeploy.Validator do
  @moduledoc false

  alias MBS.Manifest.BuildDeploy.Type
  alias MBS.Utils

  @name_regex "^[a-zA-Z0-9_-]+$"

  @spec validate([map()], Type.type(), [String.t()]) :: [map()]
  def validate(manifests, type, files_profile) do
    validate_schema(manifests, type)

    validate_unique_id(manifests)
    validate_components(manifests)
    validate_files_profile(manifests, files_profile)

    manifests
  end

  @spec validate_schema([map()], Type.type()) :: nil
  defp validate_schema(manifests, type) do
    Enum.each(manifests, fn manifest ->
      validate_id(manifest)
      validate_timeout(manifest)
      validate_type(manifest, type)
    end)

    nil
  end

  @spec validate_id(map()) :: nil
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

  @spec validate_timeout(map()) :: nil
  defp validate_timeout(%{"timeout" => timeout, "dir" => dir}) do
    unless timeout == :infinity or (is_integer(timeout) and timeout > 0) do
      message = error_message(dir, "Invalid timeout field")
      Utils.halt(message)
    end
  end

  @spec validate_docker_opts(map()) :: nil
  defp validate_docker_opts(%{"docker_opts" => docker_opts, "dir" => dir}) do
    unless is_map(docker_opts) do
      message = error_message(dir, "Bad docker_opts type")
      Utils.halt(message)
    end

    docker_opts
    |> Map.keys()
    |> Enum.each(fn docker_opts_type ->
      unless docker_opts_type in ["run", "shell"] do
        message = error_message(dir, "Bad docker_opts key #{inspect(docker_opts_type)}")
        Utils.halt(message)
      end

      validate_list_of_strings(docker_opts, [docker_opts_type], dir)
    end)

    nil
  end

  defp validate_docker_opts(_), do: nil

  @spec validate_type(map(), Type.type()) :: nil
  defp validate_type(%{"__schema__" => "toolchain", "dir" => dir} = schema, _type) do
    toolchain = schema["toolchain"]

    unless toolchain do
      message = error_message(dir, "Bad toolchain type, missing toolchain field")
      Utils.halt(message)
    end

    unless is_map(toolchain) do
      message = error_message(dir, "Bad toolchain type")
      Utils.halt(message)
    end

    unless is_binary(toolchain["dockerfile"]) do
      message = error_message(dir, "Bad dockerfile type")
      Utils.halt(message)
    end

    unless toolchain["deps_change_step"] == nil or is_binary(toolchain["deps_change_step"]) do
      message = error_message(dir, "Bad deps_change_step type")
      Utils.halt(message)
    end

    validate_list_of_strings(toolchain, ["files"], dir)
    validate_list_of_strings(toolchain, ["steps"], dir)
    validate_list_of_strings(toolchain, ["destroy_steps"], dir)

    if toolchain["docker_build_opts"] do
      validate_list_of_strings(toolchain, ["docker_build_opts"], dir)
    end
  end

  defp validate_type(%{"__schema__" => "component", "dir" => dir} = schema, type) do
    component = schema["component"]

    unless component do
      message = error_message(dir, "Bad component type, missing component field")
      Utils.halt(message)
    end

    unless is_map(component) do
      message = error_message(dir, "Bad component type")
      Utils.halt(message)
    end

    unless is_binary(component["toolchain"]) do
      message = error_message(dir, "Bad toolchain type")
      Utils.halt(message)
    end

    if type == :build do
      validate_component_build(dir, component)
    end

    validate_list_of_strings(component, ["toolchain_opts"], dir)
    validate_list_of_strings(component, ["dependencies"], dir)
    validate_docker_opts(schema)
  end

  @spec validate_component_build(Path.t(), map()) :: nil
  defp validate_component_build(dir, component) do
    unless component["files"] != nil or component["files_profile"] != nil do
      message = error_message(dir, "One of file/files_profile should be defined")
      Utils.halt(message)
    end

    unless component["files_profile"] == nil or is_binary(component["files_profile"]) do
      message = error_message(dir, "Bad files_profile type")
      Utils.halt(message)
    end

    if component["files"] != nil do
      validate_list_of_strings(component, ["files"], dir)
    end

    validate_component_services(dir, component)
    validate_list_of_strings(component, ["targets"], dir)
  end

  @spec validate_component_services(Path.t(), map()) :: nil
  defp validate_component_services(dir, component) do
    services_compose_path = component["services"]

    if services_compose_path != nil do
      unless is_binary(services_compose_path) do
        message = error_message(dir, "Bad services type")
        Utils.halt(message)
      end

      path = Path.join(dir, services_compose_path)

      unless File.exists?(path) do
        message = error_message(dir, "Bad services unknown file #{path}")
        Utils.halt(message)
      end
    end
  end

  @spec validate_list_of_strings(map(), Path.t(), Path.t()) :: nil
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

  @spec validate_unique_id([map()]) :: nil
  defp validate_unique_id(manifests) do
    ids = MapSet.new(manifests, & &1["id"])

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

  @spec validate_components([map()]) :: nil
  defp validate_components(manifests) do
    ids = MapSet.new(manifests, & &1["id"])

    toolchains_ids =
      manifests
      |> Enum.filter(&(&1["__schema__"] == "toolchain"))
      |> MapSet.new(& &1["id"])

    manifests
    |> Enum.filter(&(&1["__schema__"] == "component"))
    |> Enum.each(fn %{"dir" => dir, "component" => component} ->
      unknown_dependencies = MapSet.difference(MapSet.new(component["dependencies"] || []), ids)

      unless MapSet.size(unknown_dependencies) == 0 do
        message = error_message(dir, "Unknown dependencies #{inspect(unknown_dependencies)}")
        Utils.halt(message)
      end

      unless MapSet.member?(toolchains_ids, component["toolchain"]) do
        message = error_message(dir, "Unknown toolchain #{inspect(component["toolchain"])}")
        Utils.halt(message)
      end
    end)

    nil
  end

  @spec validate_files_profile([map()], [String.t()]) :: nil
  defp validate_files_profile(manifests, available_files_profile) do
    available_files_profile = MapSet.new(available_files_profile)

    Enum.each(manifests, fn manifest ->
      dir = manifest["dir"]
      files_profile = manifest[manifest["__schema__"]]["files_profile"]

      unless files_profile == nil or MapSet.member?(available_files_profile, files_profile) do
        message = error_message(dir, "Unknown files_profile #{files_profile}")
        Utils.halt(message)
      end
    end)

    nil
  end

  @spec error_message(Path.t(), String.t()) :: IO.chardata()
  defp error_message(dir, error_message) do
    IO.ANSI.format([:red, "Error in #{dir} manifest\n#{error_message}"])
  end
end
