defmodule Test.Command.Cache do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Test.Utils

  @test_component_a_id "test_component_a"
  @test_toolchain_id "test_toolchain_a"

  describe "cache" do
    setup :setup_clean_cache

    test "size - empty" do
      msg = capture_io(fn -> assert :ok == MBS.run(["cache", "size"], Utils.test_project_dir()) end)

      expected_msg = ~r"""
      Local cache dir:\s+#{MBS.Const.local_cache_dir()}\s+
      Local docker registry:\s+
      Completed \(0 jobs\)\s+\
      """

      assert msg =~ expected_msg
    end

    test "size - non empty" do
      msg =
        capture_io(fn -> assert :ok == MBS.run(["build", "run", @test_component_a_id], Utils.test_project_dir()) end)

      expected_msg = ~r"""
      ✔ - #{@test_toolchain_id}\s+\(.+ sec\)\s+\|\s+(?<toolchain_a_checksum>\w+)
      """

      assert msg =~ expected_msg

      re_groups = Regex.named_captures(expected_msg, msg)
      toolchain_a_checksum = re_groups["toolchain_a_checksum"]

      expected_msg = ~r"""
      ✔ - #{@test_component_a_id}\s+\(.+ sec\)\s+\|\s+(?<component_a_checksum>\w+)
      """

      assert msg =~ expected_msg
      component_a_checksum = re_groups["component_a_checksum"]

      msg = capture_io(fn -> assert :ok == MBS.run(["cache", "size"], Utils.test_project_dir()) end)

      expected_msg = ~r"""
      Local cache dir:\s+#{MBS.Const.local_cache_dir()}\s+
       0.3MB  | #{@test_component_a_id}\s+
       0.3MB  |   - #{component_a_checksum}\s+
      Local docker registry:\s+
              | #{@test_toolchain_id}\s+
      .*MB  |   - #{toolchain_a_checksum}\s+
      Completed \(0 jobs\)\s+\
      """

      assert msg =~ expected_msg
    end
  end

  defp setup_clean_cache(context), do: Utils.setup_clean_cache(context)
end
