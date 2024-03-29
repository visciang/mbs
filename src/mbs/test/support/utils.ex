defmodule Test.Utils do
  @moduledoc false

  alias MBS.Const

  def test_mbs_project_id, do: "test"
  def test_mbs_version, do: "1.2.3.test"
  def test_project_dir, do: "test/support/test_project"

  def setup_volume_dirs do
    Enum.each(
      [Const.local_cache_dir(), Const.releases_dir(), Const.graph_dir()],
      &File.rm_rf!/1
    )
  end

  def setup_env_vars do
    System.put_env("MBS_VERSION", test_mbs_version())
  end

  def setup_clean_cache(_context) do
    __MODULE__.Cache.wipe_local_cache()
    ExUnit.Callbacks.on_exit(&__MODULE__.Cache.wipe_local_cache/0)
  end

  defmodule Cache do
    @moduledoc false

    def wipe_local_cache do
      wipe_files_cache()
      wipe_all_image_tags()
    end

    defp wipe_files_cache do
      File.rm_rf!(Const.local_cache_dir())
    end

    defp wipe_all_image_tags do
      docker_label = "MBS_PROJECT_ID=#{Test.Utils.test_mbs_project_id()}"

      # credo:disable-for-next-line
      :os.cmd(
        ~c/docker image ls --filter="label=#{docker_label}" --format='{{.Repository}}:{{.Tag}}' | xargs docker image rm/
      )
    end
  end
end
