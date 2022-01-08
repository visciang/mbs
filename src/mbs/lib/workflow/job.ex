defmodule MBS.Workflow.Job do
  @moduledoc false

  defmodule FunResult do
    @moduledoc false

    defstruct [:cached]

    @type t :: %__MODULE__{
            cached: nil | boolean()
          }
  end

  @type upstream_results :: %{String.t() => FunResult.t()}
  @type fun :: (String.t(), upstream_results() -> FunResult.t())
end
