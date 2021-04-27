defmodule Test.Command.Build.Tree do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Test.Utils

  @test_component_a_id "test_component_a"
  @test_toolchain_a_id "test_toolchain_a"

  test "tree" do
    msg = capture_io(fn -> assert :ok == MBS.run(["build", "tree"], Utils.test_project_dir()) end)

    expected_output = ~r"""
    ├── #{@test_component_a_id}
    │   └── #{@test_toolchain_a_id}
    └── #{@test_toolchain_a_id}
    """

    assert msg =~ expected_output
  end
end
