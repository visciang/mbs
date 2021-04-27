defmodule Test.Utils do
  @moduledoc false

  alias MBS.Const

  def test_mbs_version, do: "1.2.3.test"

  def test_project_dir, do: "test/support/test_project"

  def setup_volume_dirs do
    Enum.each(
      [Const.tmp_dir(), Const.local_cache_dir(), Const.releases_dir(), Const.graph_dir()],
      &rm_dir_content/1
    )
  end

  def rm_dir_content(dir) do
    dir
    |> File.ls!()
    |> Enum.each(&File.rm_rf!(Path.join(dir, &1)))
  end

  def setup_env_vars do
    System.put_env("MBS_VERSION", test_mbs_version())
  end
end
