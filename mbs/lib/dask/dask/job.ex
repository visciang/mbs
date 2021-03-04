defmodule Dask.Job do
  @moduledoc false

  @type id :: term()
  @type result() :: term()
  @type job_exec_result :: {:job_ok, result()} | {:job_error, result()} | :job_skipped | :job_timeout
  @type upstream_results :: %{id() => result()}
  @type fun :: (id(), upstream_results() -> result())
  @type on_exit :: (id(), job_exec_result(), non_neg_integer() -> :ok)

  @type t :: %__MODULE__{
          id: id(),
          fun: fun(),
          timeout: timeout(),
          downstream_jobs: MapSet.t(id()),
          on_exit: on_exit()
        }
  @enforce_keys [:id, :fun, :timeout, :downstream_jobs, :on_exit]
  defstruct [:id, :fun, :timeout, :downstream_jobs, :on_exit]
end
