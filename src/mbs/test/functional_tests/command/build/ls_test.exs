defmodule Test.Command.Build.Ls do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Test.Utils

  @test_component_a_id "test_component_a"
  @test_toolchain_a_id "test_toolchain_a"
  @component_a_dir Path.absname(Path.join(Utils.test_project_dir(), @test_component_a_id))
  @toolchain_a_dir Path.absname(Path.join(Utils.test_project_dir(), @test_toolchain_a_id))

  test "ls" do
    msg = capture_io(fn -> assert :ok == MBS.Main.run(["build", "ls"], Utils.test_project_dir()) end)

    expected_output = ~r"""
    #{@test_component_a_id}  \(component\)
    #{@test_toolchain_a_id}  \(toolchain\)
    """

    assert msg =~ expected_output
  end

  test "ls --verbose (single target)" do
    msg =
      capture_io(fn ->
        assert :ok == MBS.Main.run(["build", "ls", "--verbose", @test_component_a_id], Utils.test_project_dir())
      end)

    @component_a_dir = Path.absname(Path.join(Utils.test_project_dir(), @test_component_a_id))

    expected_output = ~r"""
    #{@test_component_a_id}  \(component\):
      dir:
        #{@component_a_dir}
      timeout:
        infinity
      toolchain:
        #{@test_toolchain_a_id}
      targets:
        - #{@component_a_dir}/#{@test_component_a_id}.target_1
        - #{@component_a_dir}/#{@test_component_a_id}.target_2
      files:
        - #{@component_a_dir}/.mbs-build.json
        - #{@component_a_dir}/file_1.txt
    """

    assert msg =~ expected_output
  end

  test "ls --verbose" do
    msg = capture_io(fn -> assert :ok == MBS.Main.run(["build", "ls", "--verbose"], Utils.test_project_dir()) end)

    expected_output = ~r"""
    #{@test_component_a_id}  \(component\):
      dir:
        #{@component_a_dir}
      timeout:
        infinity
      toolchain:
        #{@test_toolchain_a_id}
      targets:
        - #{@component_a_dir}/#{@test_component_a_id}.target_1
        - #{@component_a_dir}/#{@test_component_a_id}.target_2
      files:
        - #{@component_a_dir}/.mbs-build.json
        - #{@component_a_dir}/file_1.txt

    #{@test_toolchain_a_id}  \(toolchain\):
      dir:
        #{@toolchain_a_dir}
      timeout:
        infinity
      dockerfile:
        #{@toolchain_a_dir}/Dockerfile
      steps:
        - step_1
        - step_2
      files:
        - #{@toolchain_a_dir}/.mbs-toolchain.json
        - #{@toolchain_a_dir}/Dockerfile
        - #{@toolchain_a_dir}/toolchain.sh
    """

    assert msg =~ expected_output
  end
end
