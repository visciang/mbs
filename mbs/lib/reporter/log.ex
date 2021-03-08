defmodule MBS.CLI.Reporter.Log do
  @moduledoc false
  defstruct [:reporter, :job_id]
end

defimpl Collectable, for: MBS.CLI.Reporter.Log do
  alias MBS.CLI.Reporter
  require MBS.CLI.Reporter.Status

  def into(%Reporter.Log{job_id: job_id, reporter: reporter} = original) do
    collector_fun = fn
      _, {:cont, log_message} ->
        log_message
        |> String.split(~r/\R/)
        |> Enum.each(&Reporter.job_report(reporter, job_id, Reporter.Status.log(), &1, nil))

        original

      _, :done ->
        original

      _, :halt ->
        :ok
    end

    {original, collector_fun}
  end
end
