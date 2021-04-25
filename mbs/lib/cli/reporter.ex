defmodule MBS.CLI.Reporter do
  @moduledoc """
  CLI information reporter
  """

  use GenServer

  alias MBS.CLI.Reporter.{Report, Status}

  require MBS.CLI.Reporter.Status

  @name __MODULE__

  @time_unit :millisecond
  @time_unit_scale 0.001

  defmodule State do
    @moduledoc false

    defstruct [:start_time, :success_jobs, :failed_jobs]

    @type t :: %__MODULE__{
            start_time: integer(),
            failed_jobs: [String.t()],
            success_jobs: [String.t()]
          }
  end

  @spec start_link :: :ok
  def start_link do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [start_time: time()], name: @name)
    :ok
  end

  @spec stop(:ok | :error | :timeout) :: :ok
  def stop(workflow_status) do
    GenServer.call(@name, {:stop, workflow_status})
  end

  @spec mute(boolean()) :: :ok
  def mute(status) do
    GenServer.call(@name, {:mute, status})
  end

  @spec logs(boolean()) :: :ok
  def logs(enabled) do
    GenServer.call(@name, {:logs, enabled})
  end

  @spec job_report(String.t(), Status.t(), nil | String.t(), nil | non_neg_integer()) :: :ok
  def job_report(job_id, status, description, elapsed) do
    report? =
      cond do
        :ets.lookup_element(@name, :muted, 2) -> false
        status == Status.log() and not :ets.lookup_element(@name, :logs_enabled, 2) -> false
        true -> true
      end

    if report? do
      GenServer.call(@name, %Report{job_id: job_id, status: status, description: description, elapsed: elapsed})
    else
      :ok
    end
  end

  @spec time :: integer()
  def time do
    System.monotonic_time(@time_unit)
  end

  @impl true
  @spec init(start_time: integer()) :: {:ok, MBS.CLI.Reporter.State.t()}
  def init(start_time: start_time) do
    :ets.new(@name, [:named_table])
    :ets.insert(@name, [{:muted, false}, {:logs_enabled, false}])

    {:ok, %State{start_time: start_time, success_jobs: [], failed_jobs: []}}
  end

  @impl true
  def handle_call(
        %Report{job_id: job_id, status: status, description: description, elapsed: elapsed},
        _from,
        %State{} = state
      ) do
    {status_icon, status_info} = status_icon_info(status)

    duration = if elapsed != nil, do: " (#{delta_time_string(elapsed)})", else: ""
    description = if description != nil, do: "~ #{description}", else: ""

    job_id =
      if status == Status.log() do
        IO.ANSI.format([:yellow, job_id])
      else
        job_id
      end

    puts(IO.ANSI.format([status_icon, " - ", :bright, job_id, :normal, "  ", duration, " ", description]))

    if status_info, do: puts("  - #{status_info}")

    state = track_jobs(job_id, status, state)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:mute, status}, _from, %State{} = state) do
    :ets.insert(@name, {:muted, status})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:logs, enabled}, _from, %State{} = state) do
    :ets.insert(@name, {:logs_enabled, enabled})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:stop, reason}, _from, %State{success_jobs: success_jobs, failed_jobs: failed_jobs} = state) do
    end_time = time()

    success_jobs_count = length(success_jobs)

    log_message =
      case reason do
        :ok -> IO.ANSI.format([:green, "Completed (#{success_jobs_count} jobs)"])
        :error -> IO.ANSI.format([:red, "Failed jobs:", :normal, Enum.map(Enum.sort(failed_jobs), &"\n- #{&1}"), "\n"])
        :timeout -> IO.ANSI.format([:red, "Timeout"])
      end

    duration = delta_time_string(end_time - state.start_time)

    puts("\n#{log_message} (#{duration})")

    {:stop, :normal, :ok, state}
  end

  @spec track_jobs(String.t(), Status.t(), State.t()) :: State.t()
  defp track_jobs(job_id, status, state) do
    case status do
      Status.error(_reason) -> put_in(state.failed_jobs, [job_id | state.failed_jobs])
      Status.ok() -> put_in(state.success_jobs, [job_id | state.success_jobs])
      Status.uptodate() -> put_in(state.success_jobs, [job_id | state.success_jobs])
      _ -> state
    end
  end

  @spec delta_time_string(number()) :: String.t()
  defp delta_time_string(elapsed) do
    Dask.Utils.seconds_to_compound_duration(elapsed * @time_unit_scale)
  end

  @spec status_icon_info(Status.t()) :: {IO.chardata(), nil | IO.chardata()}
  defp status_icon_info(status) do
    case status do
      Status.ok() -> {IO.ANSI.format([:green, "✔"]), nil}
      Status.error(reason) -> {IO.ANSI.format([:red, "✘"]), inspect(reason)}
      Status.uptodate() -> {"✔", nil}
      Status.outdated() -> {IO.ANSI.format([:yellow, "!"]), nil}
      Status.timeout() -> {"⏰", nil}
      Status.log() -> {".", nil}
    end
  end

  @spec puts(IO.chardata()) :: :ok
  defp puts(message) do
    unless :ets.lookup_element(@name, :muted, 2) do
      IO.puts(message)
    end

    :ok
  end
end
