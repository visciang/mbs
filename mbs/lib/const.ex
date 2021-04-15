defmodule MBS.Const do
  @moduledoc """
  MBS constants
  """

  @spec config_file :: String.t()
  def config_file, do: ".mbs-config.json"

  @spec manifest_project_filename :: String.t()
  def manifest_project_filename, do: ".mbs-project.json"

  @spec manifest_build_filename :: String.t()
  def manifest_build_filename, do: ".mbs-build.json"

  @spec manifest_deploy_filename :: String.t()
  def manifest_deploy_filename, do: ".mbs-deploy.json"

  @spec manifest_toolchain_filename :: String.t()
  def manifest_toolchain_filename, do: ".mbs-toolchain.json"

  @spec manifest_release_filename :: Path.t()
  def manifest_release_filename, do: "mbs-release.json"

  @spec manifest_dependency_filename :: Path.t()
  def manifest_dependency_filename, do: "mbs-dependency.json"

  @spec release_metadata_filename :: Path.t()
  def release_metadata_filename, do: "metadata.json"

  @spec cache_dir :: Path.t()
  def cache_dir, do: "/.mbs-cache"

  @spec push :: boolean()
  def push do
    case System.get_env("MBS_PUSH", "false") do
      "true" -> true
      "false" -> false
      "" -> false
      unknown -> raise "MBS_PUSH bad value: #{unknown}"
    end
  end

  @spec local_cache_dir :: Path.t()
  def local_cache_dir, do: "/.mbs-local-cache"

  @spec docker_registry :: String.t()
  def docker_registry do
    System.get_env("MBS_DOCKER_REGISTRY", "")
  end

  @spec releases_dir :: Path.t()
  def releases_dir, do: "/.mbs-releases"

  @spec graph_dir :: Path.t()
  def graph_dir, do: "/.mbs-graph"

  @spec local_dependencies_targets_dir :: Path.t()
  def local_dependencies_targets_dir, do: ".deps"
end
