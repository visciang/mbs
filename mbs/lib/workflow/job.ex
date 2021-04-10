defmodule MBS.Workflow.Job do
  @moduledoc """
  Workflow job logic
  """

  alias MBS.Manifest.BuildDeploy.Target

  defmodule FunResult do
    @moduledoc """
    Job function result data
    """

    defstruct [:cached, :checksum, :targets]

    @type t :: %__MODULE__{
            cached: boolean(),
            checksum: String.t(),
            targets: nil | MapSet.t({String.t(), Target.t()})
          }
  end

  @type upstream_results :: %{String.t() => FunResult.t()}
  @type fun :: (String.t(), upstream_results() -> FunResult.t())
end
