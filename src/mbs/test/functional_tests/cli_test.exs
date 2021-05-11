defmodule Test.CLI do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Test.Utils

  @mbs_subcommands [
    "build graph",
    "build ls",
    "build outdated",
    "build run",
    "build shell",
    "build tree",
    "release ls",
    "release make",
    "release rm",
    "deploy destroy",
    "deploy graph",
    "deploy ls",
    "deploy run",
    "deploy tree"
  ]

  describe "CLI args" do
    test "--help" do
      Enum.each(["" | @mbs_subcommands], fn subcommand ->
        msg =
          capture_io(fn ->
            assert :ok == MBS.run(String.split(subcommand) ++ ["--help"], Utils.test_project_dir())
          end)

        assert msg =~ ~r/Usage:  mbs #{subcommand}\s*--help/
      end)
    end

    test "bad options" do
      Enum.each(@mbs_subcommands, fn subcommand ->
        msg =
          capture_io(fn ->
            assert :error == MBS.run(String.split(subcommand) ++ ["--bad-opts"], Utils.test_project_dir())
          end)

        assert msg =~ ~r/Unknown option/
      end)
    end
  end
end
