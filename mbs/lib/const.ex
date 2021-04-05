defmodule MBS.Const do
  @moduledoc """
  MBS constants
  """

  @spec config_file() :: String.t()
  def config_file, do: ".mbs-config.json"

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

  @spec releases_dir :: Path.t()
  def releases_dir, do: "/.mbs-releases"

  @spec graph_dir :: Path.t()
  def graph_dir, do: "/.mbs-graph"

  @spec local_dependencies_targets_dir :: Path.t()
  def local_dependencies_targets_dir, do: ".deps"

  @spec mbs_dirs :: [Path.t()]
  def mbs_dirs, do: [cache_dir(), releases_dir(), graph_dir()]
end
