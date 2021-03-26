defmodule MBS.Utils do
  @moduledoc """
  Utilities
  """

  @dialyzer {:nowarn_function, halt: 1}

  @spec halt(nil | String.t(), non_neg_integer()) :: no_return()
  def halt(message, exit_status \\ 1) do
    if message != nil and message != "" do
      IO.puts(:stderr, IO.ANSI.format([:red, message]))
    end

    System.halt(exit_status)
  end
end
