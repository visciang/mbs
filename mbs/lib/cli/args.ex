defmodule MBS.CLI.Args do
  @moduledoc """
  Cli arguments
  """

  alias MBS.CLI.{Command, Reporter}
  alias MBS.{Const, Utils}

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
    IO.puts("  release ls        List available releases")
    IO.puts("  release make      Make a deployable release")
    IO.puts("  release rm        Delete a release")
    IO.puts("  ---------------------------------------------")
    IO.puts("  deploy destroy    Destroy a release deploy")
    IO.puts("  deploy graph      Generate dependency graph")
    IO.puts("  deploy ls         List available targets")
    IO.puts("  deploy run        Run a release deploy")
    IO.puts("  deploy tree       Display a dependency tree")
    IO.puts("  ---------------------------------------------")
    IO.puts("")
    IO.puts("\nRun 'mbs COMMAND [SUBCOMMAND] --help' for more information.")

    :ok
  end

  def parse(["version" | _args]) do
    %Command.Version{}
  end

  def parse([type, "tree" | args]) when type == "build" or type == "deploy" do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs #{type} tree --help | [TARGETS...]")
      IO.puts("\nDisplay the dependency tree for the provided targets (default: all targets)")

      :ok
    else
      %Command.Tree{type: String.to_atom(type), targets: targets}
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse([type, "ls" | args]) when type == "build" or type == "deploy" do
    defaults = [verbose: false]

    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs #{type} ls --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nList available targets (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --verbose    Show target details")

      :ok
    else
      options = Keyword.merge(defaults, options)
      %Command.Ls{type: String.to_atom(type), verbose: options[:verbose], targets: targets}
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse([type, "graph" | args]) when type == "build" or type == "deploy" do
    default_output_filename = "graph.svg"
    defaults = [output_filename: default_output_filename]

    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, output_filename: :string])

    if options[:help] do
      IO.puts("\nUsage:  mbs #{type} graph --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nGenerate SVG dependency graph for the requested targets (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --output-filename    Output file (default: '#{default_output_filename}')")

      :ok
    else
      options = Keyword.merge(defaults, options)
      options = put_in(options[:output_filename], Path.join(Const.graph_dir(), options[:output_filename]))

      %Command.Graph{type: String.to_atom(type), targets: targets, output_filename: options[:output_filename]}
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse(["build", "run" | args]) do
    defaults = [sandbox: false, force: false]

    {options, targets} =
      OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean, force: :boolean, sandbox: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs build run --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nRun a target(s) build (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --verbose    Stream jobs log to the console")
      IO.puts("  --force      Skip cache and force a re-run")
      IO.puts("  --sandbox    Filesystem sandbox mode (default: no sandbox)")

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
      IO.puts(e.message)
      :error
  end

  def parse(["build", "outdated" | args]) do
    {options, _} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs build outdated --help")
      IO.puts("\nShow outdated targets")

      :ok
    else
      %Command.Outdated{}
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse(["build", "shell" | args]) do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, docker_cmd: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs build shell --help | TARGET")
      IO.puts("\nInteractive toolchain shell")

      :ok
    else
      case targets do
        [target] ->
          %Command.Shell{target: target, docker_cmd: options[:docker_cmd]}

        _ ->
          IO.puts("Expected exactly one shell target")

          :error
      end
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse(["release", "ls" | args]) do
    defaults = [verbose: false]

    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs release ls --help | [OPTIONS] [TARGETS...]")
      IO.puts("\nList available releases (default: all targets)")
      IO.puts("\nOptions:")
      IO.puts("  --verbose    Show release details")

      :ok
    else
      options = Keyword.merge(defaults, options)
      %Command.LsRelease{verbose: options[:verbose], targets: targets}
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
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
        IO.puts("\nUsage:  mbs release make --help | [OPTIONS] [TARGETS...]")
        IO.puts("\nMake a release (default: all targets) - output dir '#{Const.releases_dir()}/<id>/')")
        IO.puts("\nOptions:")
        IO.puts("  --id          release identifier")
        IO.puts("  --verbose     Stream jobs log to the console")
        IO.puts("  --metadata    Extra metadata to include in the release manifest")
        IO.puts("                ex: --metadata='git_commit=...'")

        :ok

      options[:id] == nil ->
        IO.puts("Missing release --id")

        :error

      true ->
        if options[:verbose] do
          Reporter.logs(options[:verbose])
        end

        %Command.MakeRelease{id: options[:id], targets: targets, metadata: options[:metadata]}
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse(["release", "rm" | args]) do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs release rm --help | TARGET")
      IO.puts("\nDelete a release")

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
      IO.puts(e.message)
      :error
  end

  def parse(["deploy", "run" | args]) do
    defaults = [force: false]

    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean, force: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs deploy run --help | [OPTIONS] RELEASE-ID")
      IO.puts("\nRun a release deploy")
      IO.puts("\nRelease id:")
      IO.puts("  The release identifier (ref. 'mbs release --id=RELEASE-ID')")
      IO.puts("\nOptions:")
      IO.puts("  --verbose    Stream jobs log to the console")
      IO.puts("  --force      Force a re-run")

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
          IO.puts("Expected exactly one release-id")

          :error
      end
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse(["deploy", "destroy" | args]) do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])

    if options[:help] do
      IO.puts("\nUsage:  mbs deploy destroy --help | [OPTIONS] RELEASE-ID")
      IO.puts("\nDestroy a release deploy")
      IO.puts("\nRelease id:")
      IO.puts("  The release identifier (ref. 'mbs release --id=RELEASE-ID')")
      IO.puts("\nOptions:")
      IO.puts("  --verbose    Stream jobs log to the console")

      :ok
    else
      case targets do
        [release_id] ->
          if options[:verbose] do
            Reporter.logs(options[:verbose])
          end

          %Command.Destroy{release_id: release_id}

        _ ->
          IO.puts("Expected exactly one release-id")

          :error
      end
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse([type, "--help"]) when type == "build" or type == "deploy" or type == "release" do
    parse(["--help"])
  end

  def parse(args) do
    IO.puts("Unknown command #{inspect(args)}")
    :error
  end
end
