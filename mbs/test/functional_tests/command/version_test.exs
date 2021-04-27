defmodule Test.Command.Version do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Test.Utils

  test "version" do
    msg = capture_io(fn -> assert :ok == MBS.run(["version"], Utils.test_project_dir()) end)

    assert msg |> String.contains?("#{Utils.test_mbs_version()}\n")
  end
end
