defmodule MBS.CLI.Args do
  @moduledoc false

  alias MBS.CLI.{Command, Reporter}
  alias MBS.{Const, Utils}

  @type t ::
          :ok
          | :error
          | %Command.CacheSize{}
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
    IO.puts("""

    Usage:  mbs --help | (build | deploy) [SUBCOMMAND] | version")

    A Meta Build System

    Commands:

      ---------------------------------------------
      version           Show the mbs version
      ---------------------------------------------
      build graph       Generate dependency graph
      build ls          List available targets
      build outdated    Show outdated targets
      build run         Run a target build
      build shell       Interactive toolchain shell
      build tree        Display a dependency tree
      ---------------------------------------------
      release ls        List available releases
      release make      Make a deployable release
      release rm        Delete a release
      ---------------------------------------------
      deploy destroy    Destroy a release deploy
      deploy graph      Generate dependency graph
      deploy ls         List available targets
      deploy run        Run a release deploy
      deploy tree       Display a dependency tree
      ---------------------------------------------
      cache size        Used disk space
      cache prune       Remove cache
      ---------------------------------------------


    Run 'mbs COMMAND [SUBCOMMAND] --help' for more information.
    """)

    :ok
  end

  def parse(["version" | _args]) do
    %Command.Version{}
  end

  def parse(["cache", "size" | args]) do
    {options, _} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      IO.puts("""

      Usage:  mbs cache size

      Show cache used disk space
      """)

      :ok
    else
      %Command.CacheSize{}
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse(["cache", "prune" | args]) do
    {options, _} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      IO.puts("""

      Usage:  mbs cache size

      Prune the local file cache and the docker registry
      """)

      :ok
    else
      %Command.CachePrune{}
    end
  rescue
    e in [OptionParser.ParseError] ->
      IO.puts(e.message)
      :error
  end

  def parse([type, "tree" | args]) when type == "build" or type == "deploy" do
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean])

    if options[:help] do
      IO.puts("""

      Usage:  mbs #{type} tree [TARGETS...]

      Display the dependency tree for the provided targets (default: all targets)
      """)

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
      IO.puts("""

      Usage:  mbs #{type} ls [OPTIONS] [TARGETS...]

      List available targets (default: all targets)

      Options:
        --verbose    Show target details
      """)

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
      IO.puts("""

      Usage:  mbs #{type} graph [OPTIONS] [TARGETS...]

      Generate SVG dependency graph for the requested targets (default: all targets)

      Options:
        --output-filename    Output file (default: '#{default_output_filename}')
      """)

      :ok
    else
      options = Keyword.merge(defaults, options)
      options = update_in(options[:output_filename], &Path.join(Const.graph_dir(), &1))

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
      IO.puts("""

      Usage:  mbs build run [OPTIONS] [TARGETS...]

      Run a target(s) build (default: all targets)

      Options:
        --verbose    Stream jobs log to the console
        --force      Skip cache and force a re-run
        --sandbox    Filesystem sandbox mode (default: no sandbox)
      """)

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
      IO.puts("""

      Usage:  mbs build outdated --help

      Show outdated targets
      """)

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
      IO.puts("""

      Usage:  mbs build shell TARGET

      Interactive toolchain shell
      """)

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
      IO.puts("""

      Usage:  mbs release ls [OPTIONS] [TARGETS...]

      List available releases (default: all targets)

      Options:
        --verbose    Show release details
      """)

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
        IO.puts("""

        Usage:  mbs release make [OPTIONS] [TARGETS...]

        Make a release (default: all targets) - output dir '#{Const.releases_dir()}/<id>/')

        Options:
          --id          release identifier
          --verbose     Stream jobs log to the console
          --metadata    Extra metadata to include in the release manifest
                        ex: --metadata='git_commit=...'
        """)

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
      IO.puts("""

      Usage:  mbs release rm TARGET

      Delete a release
      """)

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
    {options, targets} = OptionParser.parse!(args, strict: [help: :boolean, verbose: :boolean])

    if options[:help] do
      IO.puts("""

      Usage:  mbs deploy run [OPTIONS] RELEASE-ID

      Run a release deploy

      Release id:
        The release identifier (ref. 'mbs release --id=RELEASE-ID')

      Options:
        --verbose    Stream jobs log to the console
      """)

      :ok
    else
      case targets do
        [release_id] ->
          if options[:verbose] do
            Reporter.logs(options[:verbose])
          end

          %Command.RunDeploy{release_id: release_id}

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
      IO.puts("""

      Usage:  mbs deploy destroy [OPTIONS] RELEASE-ID

      Destroy a release deploy

      Release id:
        The release identifier (ref. 'mbs release --id=RELEASE-ID')

      Options:
        --verbose    Stream jobs log to the console
      """)

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
