defmodule MBS.CLI.Reporter.Log do
  @moduledoc false

  defstruct [:job_id]

  @type t :: %__MODULE__{
          job_id: String.t()
        }
end

defimpl Collectable, for: MBS.CLI.Reporter.Log do
  alias MBS.CLI.Reporter
  require MBS.CLI.Reporter.Status

  @spec into(Reporter.Log.t()) :: {Reporter.Log.t(), (any(), :done | :halt | {:cont, any()} -> :ok | Reporter.Log.t())}
  def into(%Reporter.Log{job_id: job_id} = original) do
    collector_fun = fn
      _, {:cont, log_message} ->
        log_message
        |> String.split(~r/\R/)
        |> Enum.each(&Reporter.job_report(job_id, Reporter.Status.log(), &1, nil))

        original

      _, :done ->
        original

      _, :halt ->
        :ok
    end

    {original, collector_fun}
  end
end
