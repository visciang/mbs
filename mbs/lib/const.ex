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

  @spec releases_dir :: Path.t()
  def releases_dir, do: ".mbs-releases"

  @spec release_metadata :: Path.t()
  def release_metadata, do: "metadata.json"

  @spec graph_dir :: Path.t()
  def graph_dir, do: ".mbs-graph"

  @spec mbs_dirs :: [Path.t()]
  def mbs_dirs, do: [releases_dir(), graph_dir()]
end
