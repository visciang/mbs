defmodule MBS.Workflow.Job do
  @moduledoc """
  Workflow job logic
  """

  defmodule FunResult do
    @moduledoc """
    Job function result data
    """

    defstruct [:checksum, :targets]

    @type t :: %__MODULE__{
            checksum: String.t(),
            targets: [String.t()]
          }
  end

  @type job_fun :: (String.t(), Dask.Job.upstream_results() -> FunResult.t())
end
