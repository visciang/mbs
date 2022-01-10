defmodule MBS.CLI.Reporter.Status do
  @moduledoc false

  @type t :: :ok | :uptodate | :outdated | :timeout | :log | {:error, term(), nil | String.t()}

  defmacro ok, do: :ok
  defmacro uptodate, do: :uptodate
  defmacro outdated, do: :outdated
  defmacro timeout, do: :timeout
  defmacro log, do: :log

  defmacro error(reason, stacktrace) do
    quote do
      {:error, unquote(reason), unquote(stacktrace)}
    end
  end
end
