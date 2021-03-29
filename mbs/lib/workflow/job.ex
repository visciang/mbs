defmodule MBS.Workflow.Job do
  @moduledoc """
  Workflow job logic
  """

  alias MBS.Manifest.Target

  defmodule FunResult do
    @moduledoc """
    Job function result data
    """

    defstruct [:checksum, :targets]

    @type t :: %__MODULE__{
            checksum: String.t(),
            targets: nil | MapSet.t({String.t(), Target.t()})
          }
  end

  @type job_fun :: (String.t(), Dask.Job.upstream_results() -> FunResult.t())
end
