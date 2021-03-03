defmodule MBS.CLI.Args do
  @moduledoc """
  Cli arguments
  """

  alias MBS.Utils

  defmodule Version do
    @moduledoc false
    defstruct []
  end

  defmodule Tree do
    @moduledoc false
    defstruct [:targets]
  end

  defmodule Ls do
    @moduledoc false
    defstruct [:verbose, :targets]
  end

  defmodule Graph do
    @moduledoc false
    defstruct [:png_file]
  end

  defmodule Run do
    @moduledoc false
    defstruct [:targets]
  end

  defmodule Outdated do
    @moduledoc false
    defstruct [:dry]
  end

  def parse(["version" | _args]) do
    %Version{}
  end

  def parse(["tree" | args]) do
    {_options, targets} =
      try do
        OptionParser.parse!(args, strict: [])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    %Tree{targets: targets}
  end

  def parse(["ls" | args]) do
    defaults = [verbose: false]

    {options, targets} =
      try do
        OptionParser.parse!(args, strict: [verbose: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    options = Keyword.merge(defaults, options)
    %Ls{verbose: options[:verbose], targets: targets}
  end

  def parse(["graph", png_file]) do
    %Graph{png_file: png_file}
  end

  def parse(["run" | args]) do
    {_options, targets} =
      try do
        OptionParser.parse!(args, strict: [])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    %Run{targets: targets}
  end

  def parse(["outdated" | _args]) do
    %Outdated{}
  end

  def parse([cmd | _args]) do
    Utils.halt("Unknown command #{cmd}")
  end

  def parse([]) do
    Utils.halt("No command specified")
  end
end
