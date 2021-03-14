defmodule MBS.Workflow.Job.JobFunResult do
  @moduledoc """
  Job function result data
  """

  defstruct [:checksum, :targets]

  @type t :: %__MODULE__{
          checksum: String.t(),
          targets: [String.t()]
        }
end
