defmodule Test.Command.Build.Run do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias MBS.Const
  alias MBS.Docker
  alias Test.Utils

  @test_component_a_id "test_component_a"
  @test_toolchain_a_id "test_toolchain_a"

  test "graph" do
    msg = capture_io(fn -> MBS.run(["build", "graph", "--output-filename", "test.svg"], Utils.test_project_dir()) end)

    expected_file = Path.join(Const.graph_dir(), "test.svg")

    expected_msg = ~r"""
    Produced #{expected_file}
    """

    assert msg =~ expected_msg
    assert File.exists?(expected_file)
  end

  describe "outdated" do
    setup :setup_clean_cache

    test "first time build" do
      msg = capture_io(fn -> assert :ok == MBS.run(["build", "outdated"], Utils.test_project_dir()) end)

      assert msg =~ ~r/! - #{@test_component_a_id}\s+\|\s+\w+/
      assert msg =~ ~r/! - #{@test_toolchain_a_id}\s+\|\s+\w+/
    end
  end

  describe "run" do
    setup :setup_clean_cache

    defp build_run do
      msg = capture_io(fn -> MBS.run(["build", "run", "--sandbox"], Utils.test_project_dir()) end)

      expected_msg = ~r"""
      ✔ - #{@test_toolchain_a_id}\s+\(.+ sec\)\s+\|\s+(?<toolchain_a_checksum>\w+)
      ✔ - #{@test_component_a_id}:step_1\s+\(.+ sec\)\s+
      ✔ - #{@test_component_a_id}:step_2\s+\(.+ sec\)\s+
      ✔ - #{@test_component_a_id}\s+\(.+ sec\)\s+\|\s+(?<component_a_checksum>\w+)

      Completed \(4 jobs\) \(.* sec\)
      """

      assert msg =~ expected_msg

      re_groups = Regex.named_captures(expected_msg, msg)
      %{"toolchain_a_checksum" => toolchain_a_checksum, "component_a_checksum" => component_a_checksum} = re_groups

      {toolchain_a_checksum, component_a_checksum}
    end

    test "all targets" do
      {toolchain_a_checksum, component_a_checksum} = build_run()

      component_a_cache_path = Path.join([Const.local_cache_dir(), @test_component_a_id, component_a_checksum])
      assert File.exists?(component_a_cache_path)

      expected_component_a_targets = ["#{@test_component_a_id}.target_1", "#{@test_component_a_id}.target_2"]
      component_a_targets = File.ls!(component_a_cache_path) |> Enum.sort()
      assert expected_component_a_targets == component_a_targets

      assert Docker.image_exists(@test_toolchain_a_id, toolchain_a_checksum)
    end

    test "correct caching" do
      {toolchain_a_checksum, component_a_checksum} = build_run()

      # re-run -> should be all cached

      msg = capture_io(fn -> assert :ok == MBS.run(["build", "run", "--sandbox"], Utils.test_project_dir()) end)

      expected_msg = ~r"""
      ✔ - #{@test_toolchain_a_id}\s+\(.+ sec\)\s+\|\s+#{toolchain_a_checksum}
      ✔ - #{@test_component_a_id}\s+\(.+ sec\)\s+\|\s+#{component_a_checksum}

      Completed \(2 jobs\) \(.* sec\)
      """

      assert msg =~ expected_msg
    end

    test "re-build on target miss" do
      {toolchain_a_checksum, component_a_checksum} = build_run()

      # rm component target -> component re-build

      component_a_target_cache_path =
        Path.join([
          Const.local_cache_dir(),
          @test_component_a_id,
          component_a_checksum,
          "#{@test_component_a_id}.target_1"
        ])

      File.rm!(component_a_target_cache_path)

      msg = capture_io(fn -> assert :ok == MBS.run(["build", "outdated"], Utils.test_project_dir()) end)

      assert msg =~ ~r/! - #{@test_component_a_id}   \| #{component_a_checksum}/

      msg = capture_io(fn -> assert :ok == MBS.run(["build", "run", "--sandbox"], Utils.test_project_dir()) end)

      expected_msg = ~r"""
      ✔ - #{@test_toolchain_a_id}\s+\(.+ sec\)\s+\|\s+#{toolchain_a_checksum}
      ✔ - #{@test_component_a_id}:step_1   \(.+ sec\)\s+
      ✔ - #{@test_component_a_id}:step_2   \(.+ sec\)\s+
      ✔ - #{@test_component_a_id}\s+\(.+ sec\)\s+\|\s+#{component_a_checksum}

      Completed \(4 jobs\) \(.* sec\)
      """

      assert msg =~ expected_msg
    end

    test "re-build on input file change" do
      file_path = Path.join([Utils.test_project_dir(), @test_component_a_id, "file_test.txt"])

      on_exit(fn -> File.rm_rf!(file_path) end)

      {_toolchain_a_checksum, component_a_checksum} = build_run()

      # change input file -> component re-build

      File.write!(file_path, "test")

      msg = capture_io(fn -> assert :ok == MBS.run(["build", "outdated"], Utils.test_project_dir()) end)

      expected_msg = ~r/! - #{@test_component_a_id}\s+\|\s+(?<new_component_a_checksum>\w+)/

      assert msg =~ expected_msg

      re_groups = Regex.named_captures(expected_msg, msg)
      %{"new_component_a_checksum" => new_component_a_checksum} = re_groups

      assert new_component_a_checksum != component_a_checksum

      # revert -> component uptodate (previous build cached)

      File.rm!(file_path)

      msg = capture_io(fn -> assert :ok == MBS.run(["build", "outdated"], Utils.test_project_dir()) end)

      assert msg =~ ~r/Completed \(0 jobs\)/
    end
  end

  defp setup_clean_cache(context), do: Utils.setup_clean_cache(context)
end
