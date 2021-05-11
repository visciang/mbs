defmodule MBS.CLI.Reporter.Status do
  @moduledoc false

  @type t :: :ok | :uptodate | :outdated | :timeout | :log | {:error, term()}

  defmacro ok, do: :ok
  defmacro uptodate, do: :uptodate
  defmacro outdated, do: :outdated
  defmacro timeout, do: :timeout
  defmacro log, do: :log

  defmacro error(reason) do
    quote do
      {:error, unquote(reason)}
    end
  end
end
