defmodule MBS.CLI.Args do
  @moduledoc """
  Cli arguments
  """

  alias MBS.CLI.{Command, Reporter}
  alias MBS.{Const, Utils}

  @type t ::
          %Command.Graph{}
          | %Command.Destroy{}
          | %Command.Ls{}
          | %Command.Outdated{}
          | %Command.Release{}
          | %Command.RunBuild{}
          | %Command.RunDeploy{}
          | %Command.Shell{}
          | %Command.Tree{}
          | %Command.Version{}

  @spec parse([String.t()]) :: t()
  def parse([]) do
    parse(["--help"])
  end

  def parse(["--help"]) do
    IO.puts("\nUsage:  mbs --help | (build | deploy) [SUBCOMMAND] | version")
    IO.puts("\nA Meta Build System")
    IO.puts("\nCommands:")
    IO.puts("")
    IO.puts("  ---------------------------------------------")
    IO.puts("  version           Show the mbs version")
    IO.puts("  ---------------------------------------------")
    IO.puts("  build graph       Generate dependency graph")
    IO.puts("  build ls          List available targets")
    IO.puts("  build outdated    Show outdated targets")
    IO.puts("  build run         Run a target build")
    IO.puts("  build shell       Interactive toolchain shell")
    IO.puts("  build tree        Display a dependency tree")
    IO.puts("  ---------------------------------------------")
    IO.puts("  release           Make a deployable release")
    IO.puts("  ---------------------------------------------")
    IO.puts("  deploy destroy    Destroy a release deploy")
    IO.puts("  deploy graph      Generate dependency graph")
    IO.puts("  deploy ls         List available targets")
    IO.puts("  deploy run        Run a release deploy")
    IO.puts("  deploy tree       Display a dependency tree")
    IO.puts("  ---------------------------------------------")
    IO.puts("")
    IO.puts("\nRun 'mbs COMMAND [SUBCOMMAND] --help' for more information.")

    Utils.halt(nil, 0)
  end

  def parse(["version" | _args]) do
    %Command.Version{}
  end

  def parse([type, "tree" | args]) when type == "build" or type == "deploy" do
    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs #{type} tree --help | [TARGETS...]")
      IO.puts("\nDisplay the dependency tree for the provided targets (default: all targets)")

      Utils.halt(nil, 0)
    end

    %Command.Tree{type: String.to_atom(type), targets: targets}
  end

  def parse([type, "ls" | args]) when type == "build" or type == "deploy" do
    defaults = [verbose: false]

    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs #{type} ls --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nList available targets (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --verbose    Show target details")

      Utils.halt(nil, 0)
    end

    options = Keyword.merge(defaults, options)
    %Command.Ls{type: String.to_atom(type), verbose: options[:verbose], targets: targets}
  end

  def parse([type, "graph" | args]) when type == "build" or type == "deploy" do
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
      IO.puts("\nUsage:  mbs #{type} graph --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nGenerate SVG dependency graph for the requested targets (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --output-filename    Output file (default: '#{default_output_filename}')")

      Utils.halt(nil, 0)
    end

    options = Keyword.merge(defaults, options)
    options = put_in(options[:output_filename], Path.join(Const.graph_dir(), options[:output_filename]))

    %Command.Graph{type: String.to_atom(type), targets: targets, output_filename: options[:output_filename]}
  end

  def parse(["build", "run" | args]) do
    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, logs: :boolean, force: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs build run --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nRun a target(s) build (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --logs     Stream jobs log to the console")
      IO.puts("  --force    Skip cache and force a re-run")
      Utils.halt(nil, 0)
    end

    if options[:logs] do
      Reporter.logs(options[:logs])
    end

    %Command.RunBuild{targets: targets, force: options[:force]}
  end

  def parse(["build", "outdated" | args]) do
    {options, _} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs build outdated --help")
      IO.puts("\nShow outdated targets")

      Utils.halt(nil, 0)
    end

    %Command.Outdated{}
  end

  def parse(["build", "shell" | args]) do
    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, docker_cmd: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs build shell --help | TARGET")
      IO.puts("\nInteractive toolchain shell")
      Utils.halt(nil, 0)
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

  def parse(["release" | args]) do
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
      IO.puts("  --logs          Stream jobs log to the console")
      IO.puts("  --metadata      Extra metadata to include in the release manifest")
      IO.puts("                  ex: --metadata='git_commit=...'")
      Utils.halt(nil, 0)
    end

    unless options[:id] do
      Utils.halt("Missing release --id")
    end

    if options[:logs] do
      Reporter.logs(options[:logs])
    end

    defaults = [output_dir: Path.join(Const.releases_dir(), options[:id])]
    options = Keyword.merge(defaults, options)

    %Command.Release{id: options[:id], targets: targets, output_dir: options[:output_dir], metadata: options[:metadata]}
  end

  def parse(["deploy", "run" | args]) do
    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, logs: :boolean, force: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs deploy run --help | [OPTIONS] RELEASE-ID")
      IO.puts("\nRun a release deploy")
      IO.puts("\nRelease id:")
      IO.puts("  The release identifier (ref. 'mbs release --id=RELEASE-ID')")
      IO.puts("\nOptions:")
      IO.puts("  --logs     Stream jobs log to the console")
      IO.puts("  --force    Force a re-run")
      Utils.halt(nil, 0)
    end

    release_id =
      case targets do
        [release_id] ->
          release_id

        _ ->
          Utils.halt("Expected exactly one release-id")
      end

    if options[:logs] do
      Reporter.logs(options[:logs])
    end

    %Command.RunDeploy{release_id: release_id, force: options[:force]}
  end

  def parse(["deploy", "destroy" | args]) do
    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [help: :boolean, logs: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    if options[:help] do
      IO.puts("\nUsage:  mbs deploy destroy --help | [OPTIONS] RELEASE-ID")
      IO.puts("\Destroy a release deploy")
      IO.puts("\nRelease id:")
      IO.puts("  The release identifier (ref. 'mbs release --id=RELEASE-ID')")
      IO.puts("\nOptions:")
      IO.puts("  --logs     Stream jobs log to the console")
      Utils.halt(nil, 0)
    end

    release_id =
      case targets do
        [release_id] ->
          release_id

        _ ->
          Utils.halt("Expected exactly one release-id")
      end

    if options[:logs] do
      Reporter.logs(options[:logs])
    end

    %Command.Destroy{release_id: release_id}
  end

  def parse([type, "--help"]) when type == "build" or type == "deploy" do
    parse(["--help"])
  end

  def parse(args) do
    Utils.halt("Unknown command #{inspect(args)}")
  end
end
