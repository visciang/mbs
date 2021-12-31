defmodule MBS.Const do
  @moduledoc false

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

  @spec manifest_release_filename :: String.t()
  def manifest_release_filename, do: "mbs-release.bin"

  @spec manifest_dependency_filename :: String.t()
  def manifest_dependency_filename, do: "mbs-dependency.json"

  @spec logs_dir :: Path.t()
  def logs_dir, do: ".mbs-logs"

  @spec cache_dir :: Path.t()
  def cache_dir, do: "/mbs/remote_cache"

  @spec local_cache_dir :: Path.t()
  def local_cache_dir, do: "/mbs/local_cache"

  @spec releases_dir :: Path.t()
  def releases_dir, do: "/mbs/releases"

  @spec graph_dir :: Path.t()
  def graph_dir, do: "/mbs/graph"

  @spec local_dependencies_targets_dir :: Path.t()
  def local_dependencies_targets_dir, do: ".deps"
end
