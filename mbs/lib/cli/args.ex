defmodule MBS.CLI.Args do
  @moduledoc """
  Cli arguments
  """

  alias MBS.CLI.{Command, Reporter}
  alias MBS.{Const, Utils}

  require Logger

  @type t ::
          :ok
          | :error
          | %Command.Graph{}
          | %Command.Destroy{}
          | %Command.Ls{}
          | %Command.LsRelease{}
          | %Command.MakeRelease{}
          | %Command.Outdated{}
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
    Logger.info("\nUsage:  mbs --help | (build | deploy) [SUBCOMMAND] | version")
    Logger.info("\nA Meta Build System")
    Logger.info("\nCommands:")
    Logger.info("")
    Logger.info("  ---------------------------------------------")
    Logger.info("  version           Show the mbs version")
    Logger.info("  ---------------------------------------------")
    Logger.info("  build graph       Generate dependency graph")
    Logger.info("  build ls          List available targets")
    Logger.info("  build outdated    Show outdated targets")
    Logger.info("  build run         Run a target build")
    Logger.info("  build shell       Interactive toolchain shell")
    Logger.info("  build tree        Display a dependency tree")
    Logger.info("  ---------------------------------------------")
    Logger.info("  release ls        List available releases")
    Logger.info("  release make      Make a deployable release")
    Logger.info("  release rm        Delete a release")
    Logger.info("  ---------------------------------------------")
    Logger.info("  deploy destroy    Destroy a release deploy")
    Logger.info("  deploy graph      Generate dependency graph")
    Logger.info("  deploy ls         List available targets")
    Logger.info("  deploy run        Run a release deploy")
    Logger.info("  deploy tree       Display a dependency tree")
    Logger.info("  ---------------------------------------------")
    Logger.info("")
    Logger.info("\nRun 'mbs COMMAND [SUBCOMMAND] --help' for more information.")

    :ok
  end

  def parse(["version" | _args]) do
    %Command.Version{}
  end

  def parse([type, "tree" | args]) when type == "build" or type == "deploy" do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs #{type} tree --help | [TARGETS...]")
      Logger.info("\nDisplay the dependency tree for the provided targets (default: all targets)")

      :ok
    else
      %Command.Tree{type: String.to_atom(type), targets: targets}
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse([type, "ls" | args]) when type == "build" or type == "deploy" do
    defaults = [verbose: false]

    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs #{type} ls --help | [OPTIONS] [TARGETS...]")
      Logger.info("\nList available targets (default: all targets)")
      Logger.info("\nOptions:")
      Logger.info("  --verbose    Show target details")

      :ok
    else
      options = Keyword.merge(defaults, options)
      %Command.Ls{type: String.to_atom(type), verbose: options[:verbose], targets: targets}
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse([type, "graph" | args]) when type == "build" or type == "deploy" do
    default_output_filename = "graph.svg"
    defaults = [output_filename: default_output_filename]

    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, output_filename: :string])

    if options[:help] do
      Logger.info("\nUsage:  mbs #{type} graph --help | [OPTIONS] [TARGETS...]")
      Logger.info("\nGenerate SVG dependency graph for the requested targets (default: all targets)")
      Logger.info("\nOptions:")
      Logger.info("  --output-filename    Output file (default: '#{default_output_filename}')")

      :ok
    else
      options = Keyword.merge(defaults, options)
      options = put_in(options[:output_filename], Path.join(Const.graph_dir(), options[:output_filename]))

      %Command.Graph{type: String.to_atom(type), targets: targets, output_filename: options[:output_filename]}
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse(["build", "run" | args]) do
    defaults = [sandbox: false, force: false]

    {options, targets} =
      OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean, force: :boolean, sandbox: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs build run --help | [OPTIONS] [TARGETS...]")
      Logger.info("\nRun a target(s) build (default: all targets)")
      Logger.info("\nOptions:")
      Logger.info("  --verbose    Stream jobs log to the console")
      Logger.info("  --force      Skip cache and force a re-run")
      Logger.info("  --sandbox    Filesystem sandbox mode (default: no sandbox)")

      :ok
    else
      if options[:verbose] do
        Reporter.logs(options[:verbose])
      end

      options = Keyword.merge(defaults, options)
      %Command.RunBuild{targets: targets, force: options[:force], sandbox: options[:sandbox], get_deps_only: false}
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse(["build", "outdated" | args]) do
    {options, _} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs build outdated --help")
      Logger.info("\nShow outdated targets")

      :ok
    else
      %Command.Outdated{}
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse(["build", "shell" | args]) do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, docker_cmd: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs build shell --help | TARGET")
      Logger.info("\nInteractive toolchain shell")

      :ok
    else
      case targets do
        [target] ->
          %Command.Shell{target: target, docker_cmd: options[:docker_cmd]}

        _ ->
          Logger.error("Expected exactly one shell target")

          :error
      end
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse(["release", "ls" | args]) do
    defaults = [verbose: false]

    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs release ls --help | [OPTIONS] [TARGETS...]")
      Logger.info("\nList available releases (default: all targets)")
      Logger.info("\nOptions:")
      Logger.info("  --verbose    Show release details")

      :ok
    else
      options = Keyword.merge(defaults, options)
      %Command.LsRelease{verbose: options[:verbose], targets: targets}
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse(["release", "make" | args]) do
    {options, targets} =
      OptionParser.parse!(
        args,
        strict: [help: :boolean, id: :string, output_dir: :string, logs: :boolean, metadata: :string]
      )

    cond do
      options[:help] ->
        Logger.info("\nUsage:  mbs release make --help | [OPTIONS] [TARGETS...]")
        Logger.info("\nMake a release (default: all targets) - output dir '#{Const.releases_dir()}/<id>/')")
        Logger.info("\nOptions:")
        Logger.info("  --id          release identifier")
        Logger.info("  --verbose     Stream jobs log to the console")
        Logger.info("  --metadata    Extra metadata to include in the release manifest")
        Logger.info("                ex: --metadata='git_commit=...'")

        :ok

      not options[:id] ->
        Logger.error("Missing release --id")

        :error

      true ->
        if options[:verbose] do
          Reporter.logs(options[:verbose])
        end

        %Command.MakeRelease{id: options[:id], targets: targets, metadata: options[:metadata]}
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse(["release", "rm" | args]) do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs release rm --help | TARGET")
      Logger.info("\nDelete a release")

      :ok
    else
      case targets do
        [target] ->
          %Command.RmRelease{target: target}

        _ ->
          Utils.halt("Expected exactly one target")
      end
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse(["deploy", "run" | args]) do
    defaults = [force: false]

    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean, force: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs deploy run --help | [OPTIONS] RELEASE-ID")
      Logger.info("\nRun a release deploy")
      Logger.info("\nRelease id:")
      Logger.info("  The release identifier (ref. 'mbs release --id=RELEASE-ID')")
      Logger.info("\nOptions:")
      Logger.info("  --verbose    Stream jobs log to the console")
      Logger.info("  --force      Force a re-run")

      :ok
    else
      case targets do
        [release_id] ->
          if options[:verbose] do
            Reporter.logs(options[:verbose])
          end

          options = Keyword.merge(defaults, options)
          %Command.RunDeploy{release_id: release_id, force: options[:force]}

        _ ->
          Logger.error("Expected exactly one release-id")

          :error
      end
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse(["deploy", "destroy" | args]) do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])

    if options[:help] do
      Logger.info("\nUsage:  mbs deploy destroy --help | [OPTIONS] RELEASE-ID")
      Logger.info("\nDestroy a release deploy")
      Logger.info("\nRelease id:")
      Logger.info("  The release identifier (ref. 'mbs release --id=RELEASE-ID')")
      Logger.info("\nOptions:")
      Logger.info("  --verbose    Stream jobs log to the console")

      :ok
    else
      case targets do
        [release_id] ->
          if options[:verbose] do
            Reporter.logs(options[:verbose])
          end

          %Command.Destroy{release_id: release_id}

        _ ->
          Logger.error("Expected exactly one release-id")

          :error
      end
    end
  rescue
    e in [OptionParser.ParseError] ->
      Logger.error(e.message)
      :error
  end

  def parse([type, "--help"]) when type == "build" or type == "deploy" or type == "release" do
    parse(["--help"])
  end

  def parse(args) do
    Logger.error("Unknown command #{inspect(args)}")
    :error
  end
end
