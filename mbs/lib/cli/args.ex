defmodule MBS.CLI.Args do
  @moduledoc """
  Cli arguments
  """

  alias MBS.CLI.{Command, Reporter}
  alias MBS.{Const, Utils}

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
    IO.puts("\nUsage:  mbs --help | (build | deploy) [SUBCOMMAND] | version")
    IO.puts("\nA Meta Build System")
    IO.puts("\nCommands:")
    IO.puts("")
    IO.puts("  build graph       Generate dependency graph")
    IO.puts("  build ls          List available targets")
    IO.puts("  build outdated    Show outdated targets")
    IO.puts("  build run         Run a target build")
    IO.puts("  build shell       Interactive toolchain shell")
    IO.puts("  build tree        Display a dependecy tree")
    IO.puts("")
    IO.puts("  deploy graph      Generate dependency graph")
    IO.puts("  deploy ls         List available targets")
    IO.puts("  deploy release    Make a release")
    IO.puts("  deploy tree       Display a dependecy tree")
    IO.puts("")
    IO.puts("  version           Show the mbs version")
    IO.puts("\nRun 'mbs COMMAND SUBCOMMAND --help' for more information.")

    Utils.halt("", 0)
  end

  def parse(["version" | _args], _reporter) do
    %Command.Version{}
  end

  def parse([type, "tree" | args], _reporter) when type == "build" or type == "deploy" do
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

    %Command.Tree{type: String.to_atom(type), targets: targets}
  end

  def parse([type, "ls" | args], _reporter) when type == "build" or type == "deploy" do
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
    %Command.Ls{type: String.to_atom(type), verbose: options[:verbose], targets: targets}
  end

  def parse([type, "graph" | args], _reporter) when type == "build" or type == "deploy" do
    default_output_filename = "graph.svg"
    defaults = [output_filename: default_output_filename]

    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, output_filename: :string])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs graph --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nGenerate SVG dependency graph for the requested targets (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --output-filename    Output file (default: '#{default_output_filename}')")

      Utils.halt("", 0)
    end

    options = Keyword.merge(defaults, options)
    options = put_in(options[:output_filename], Path.join(Const.graph_dir(), options[:output_filename]))

    %Command.Graph{type: String.to_atom(type), targets: targets, output_filename: options[:output_filename]}
  end

  def parse(["build", "run" | args], reporter) do
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

  def parse(["build", "outdated" | args], _reporter) do
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

  def parse(["build", "shell" | args], _reporter) do
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

  def parse(["deploy", "release" | args], reporter) do
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
      IO.puts("\nMake a release (default: all targets) - output dir '#{Const.releases_dir()}/<id>/')")
      IO.puts("\nOptions:")
      IO.puts("  --id            release identifier")
      IO.puts("  --output-dir    output directory (default: '#{Const.releases_dir()}/<id>/')")
      IO.puts("  --logs          Stream jobs log to the console")
      IO.puts("  --metadata      Extra metadata to include in the release manifest")
      IO.puts("                  ex: --metadata='git_commit=...'")
      Utils.halt("", 0)
    end

    unless options[:id] do
      Utils.halt("Missing release --id")
    end

    if options[:logs] do
      Reporter.logs(reporter, options[:logs])
    end

    defaults = [output_dir: Path.join(Const.releases_dir(), options[:id])]
    options = Keyword.merge(defaults, options)

    %Command.Release{id: options[:id], targets: targets, output_dir: options[:output_dir], metadata: options[:metadata]}
  end

  def parse(args, _reporter) do
    Utils.halt("Unknown command #{inspect(args)}")
  end
end
