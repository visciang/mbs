defmodule MBS.Utils do
  @moduledoc """
  Utilities
  """

  @dialyzer {:nowarn_function, halt: 1}

  @spec halt(String.t(), non_neg_integer()) :: no_return()
  def halt(message, exit_status \\ 1) do
    if message do
      IO.puts(IO.ANSI.format([:red, message], true))
    end

    System.halt(exit_status)
  end
end
