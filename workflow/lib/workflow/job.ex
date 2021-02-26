defmodule Workflow.Job do
  @moduledoc false

  @type id :: term()
  @type result() :: term()
  @type upstream_results :: %{id() => result()}
  @type fun :: (id(), upstream_results() -> result())

  @type t :: %__MODULE__{
          id: id(),
          fun: fun(),
          timeout: timeout(),
          downstream_jobs: MapSet.t(id())
        }
  @enforce_keys [:id, :fun, :timeout, :downstream_jobs]
  defstruct [:id, :fun, :timeout, :downstream_jobs]
end
