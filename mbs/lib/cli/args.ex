defmodule MBS.CLI.Args do
  @moduledoc """
  Cli arguments
  """

  alias MBS.CLI.{Command, Reporter}
  alias MBS.Utils

  @type t ::
          %Command.Graph{}
          | %Command.Ls{}
          | %Command.Outdated{}
          | %Command.Release{}
          | %Command.Run{}
          | %Command.Shell{}
          | %Command.Tree{}
          | %Command.Version{}

  @spec parse([String.t()], Reporter.t()) :: t()
  def parse([], reporter) do
    parse(["--help"], reporter)
  end

  def parse(["--help"], _reporter) do
    IO.puts("\nUsage:  mbs --help | COMMAND")
    IO.puts("\nA Meta Build System")
    IO.puts("\nCommands:")
    IO.puts("  ls          List available targets")
    IO.puts("  graph       Generate dependency graph")
    IO.puts("  outdated    Show outdated targets")
    IO.puts("  release     Make a release")
    IO.puts("  run         Run a target build")
    IO.puts("  shell       Interactive toolchain shell")
    IO.puts("  tree        Display a dependecy tree")
    IO.puts("  version     Show the mbs version")
    IO.puts("\nRun 'mbs COMMAND --help' for more information on a command.")

    Utils.halt("", 0)
  end

  def parse([command | args], reporter) do
    parse(command, args, reporter)
  end

  defp parse("version", _args, _reporter) do
    %Command.Version{}
  end

  defp parse("tree", args, _reporter) do
    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs tree --help | [TARGETS...]")
      IO.puts("\nDisplay the dependecy tree for the provided targets (default: all targets)")

      Utils.halt("", 0)
    end

    %Command.Tree{targets: targets}
  end

  defp parse("ls", args, _reporter) do
    defaults = [verbose: false]

    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs ls --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nList available targets (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --verbose    Show target details")

      Utils.halt("", 0)
    end

    options = Keyword.merge(defaults, options)
    %Command.Ls{verbose: options[:verbose], targets: targets}
  end

  defp parse("graph", args, _reporter) do
    default_output_file = "graph.svg"
    defaults = [output_svg_file: default_output_file]

    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, output_svg_file: :string])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs graph --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nGenerate SVG dependency graph for the requested targets (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --output-svg-file    Output file (default: './#{default_output_file}')")

      Utils.halt("", 0)
    end

    options = Keyword.merge(defaults, options)
    %Command.Graph{targets: targets, output_svg_file: options[:output_svg_file]}
  end

  defp parse("run", args, reporter) do
    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, logs: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs run --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nRun a target(s) build (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --logs    Stream jobs log to the console")
      Utils.halt("", 0)
    end

    if options[:logs] do
      Reporter.logs(reporter, options[:logs])
    end

    %Command.Run{targets: targets}
  end

  defp parse("release", args, reporter) do
    {options, targets} =
      try do
        OptionParser.parse!(args,
          strict: [help: :boolean, id: :string, output_dir: :string, logs: :boolean, metadata: :string]
        )
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs release --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nMake a release (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --id            release identifier")
      IO.puts("  --output-dir    output directory (default: '.mbs-releases/<id>/')")
      IO.puts("  --logs          Stream jobs log to the console")
      IO.puts("  --metadata      Extra metadata to include in the release manifest.json")
      IO.puts("                  ex: --metadata='git_commit=...'")
      Utils.halt("", 0)
    end

    unless options[:id] do
      Utils.halt("Missing release --id")
    end

    if options[:logs] do
      Reporter.logs(reporter, options[:logs])
    end

    defaults = [output_dir: Path.join(".mbs-releases", options[:id])]
    options = Keyword.merge(defaults, options)

    File.mkdir_p!(options[:output_dir])

    %Command.Release{id: options[:id], targets: targets, output_dir: options[:output_dir], metadata: options[:metadata]}
  end

  defp parse("outdated", args, _reporter) do
    {options, _} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs outdated --help")
      IO.puts("\nShow outdated targets")

      Utils.halt("", 0)
    end

    %Command.Outdated{}
  end

  defp parse("shell", args, _reporter) do
    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, docker_cmd: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs shell --help | TARGET")
      IO.puts("\nInteractive toolchain shell")
      Utils.halt("", 0)
    end

    target =
      case targets do
        [target] ->
          target

        _ ->
          Utils.halt("Expected exactly one shell target")
      end

    %Command.Shell{target: target, docker_cmd: options[:docker_cmd]}
  end

  defp parse(cmd, _args, _reporter) do
    Utils.halt("Unknown command #{cmd}")
  end
end
