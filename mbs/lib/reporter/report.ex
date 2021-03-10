defmodule MBS.CLI.Reporter.Report do
  @moduledoc false
  defstruct [:job_id, :status, :description, :elapsed]

  @type t :: %__MODULE__{
          job_id: String.t(),
          status: MBS.CLI.Reporter.Status.t()
        }
end
