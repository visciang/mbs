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
    defstruct []
  end

  defmodule Ls do
    @moduledoc false
    defstruct [:verbose]
  end

  defmodule Graph do
    @moduledoc false
    defstruct [:png_file]
  end

  defmodule Run do
    @moduledoc false
    defstruct []
  end

  defmodule Outdated do
    @moduledoc false
    defstruct [:dry]
  end

  def parse(["version" | _args]) do
    %Version{}
  end

  def parse(["tree" | _args]) do
    %Tree{}
  end

  def parse(["ls" | args]) do
    {options, _} =
      try do
        OptionParser.parse!(args, strict: [verbose: :boolean])
      rescue
        e in [OptionParser.ParseError] ->
          Utils.halt(e.message)
      end

    options = Keyword.merge([verbose: false], options)
    %Ls{verbose: options[:verbose]}
  end

  def parse(["graph", png_file]) do
    %Graph{png_file: png_file}
  end

  def parse(["run" | _args]) do
    %Run{}
  end

  def parse(["outdated" | _args]) do
    %Outdated{}
  end

  def parse([cmd | _args]) do
    Utils.halt("Unknown command #{cmd}")
  end
end
