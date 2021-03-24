defmodule MBS.CLI.Reporter do
  @moduledoc """
  CLI information reporter
  """

  use GenServer

  alias MBS.CLI.Reporter.{Report, Status}
  require MBS.CLI.Reporter.Status

  @type t() :: GenServer.server()

  @time_unit :millisecond
  @time_unit_scale 0.001

  defmodule State do
    @moduledoc false

    defstruct [:start_time, :muted, :logs_enabled]

    @type t :: %__MODULE__{
            start_time: integer(),
            muted: boolean(),
            logs_enabled: boolean()
          }
  end

  @spec start_link :: {:ok, t()}
  def start_link do
    {:ok, pid} = GenServer.start_link(__MODULE__, start_time: time())
    {:ok, pid}
  end

  @spec stop(t(), Status.t()) :: :ok
  def stop(pid, workflow_status) do
    GenServer.call(pid, {:stop, workflow_status})
  end

  @spec mute(t(), boolean()) :: :ok
  def mute(pid, status) do
    GenServer.call(pid, {:mute, status})
  end

  @spec logs(t(), boolean()) :: :ok
  def logs(pid, enabled) do
    GenServer.call(pid, {:logs, enabled})
  end

  @spec job_report(t(), String.t(), Status.t(), nil | String.t(), nil | non_neg_integer()) :: :ok
  def job_report(pid, job_id, status, description, elapsed) do
    GenServer.cast(pid, %Report{job_id: job_id, status: status, description: description, elapsed: elapsed})
  end

  @spec time :: integer()
  def time do
    System.monotonic_time(@time_unit)
  end

  @impl true
  def init(start_time: start_time) do
    {:ok, %State{start_time: start_time, muted: false, logs_enabled: false}}
  end

  @impl true
  def handle_cast(%Report{status: Status.log()}, %State{logs_enabled: false} = state) do
    {:noreply, state}
  end

  def handle_cast(%Report{job_id: job_id, status: status, description: description, elapsed: elapsed}, %State{} = state) do
    {status_icon, status_info} = status_icon_info(status)

    duration = if elapsed != nil, do: " (#{delta_time_string(elapsed)})", else: ""
    description = if description != nil, do: "~ #{description}", else: ""

    job_id =
      if status == Status.log() do
        IO.ANSI.format([:yellow, job_id])
      else
        job_id
      end

    puts(IO.ANSI.format([status_icon, " - ", :bright, job_id, :normal, "  ", duration, " ", description]), state)

    if status_info, do: IO.puts("  - #{status_info}")

    {:noreply, state}
  end

  @impl true
  def handle_call({:mute, status}, _from, %State{} = state) do
    {:reply, :ok, put_in(state.muted, status)}
  end

  @impl true
  def handle_call({:logs, enabled}, _from, %State{} = state) do
    {:reply, :ok, put_in(state.logs_enabled, enabled)}
  end

  @impl true
  def handle_call({:stop, reason}, _from, %State{} = state) do
    end_time = time()

    log_message =
      case reason do
        :ok -> IO.ANSI.format([:green, "Successfully completed"])
        :error -> IO.ANSI.format([:red, "Failed"])
        :timeout -> IO.ANSI.format([:red, "Timeout"])
      end

    duration = delta_time_string(end_time - state.start_time)

    puts("\n#{log_message} (#{duration})", state)

    {:stop, :normal, :ok, state}
  end

  defp delta_time_string(elapsed) do
    Dask.Utils.seconds_to_compound_duration(elapsed * @time_unit_scale)
  end

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

  defp puts(message, %State{muted: muted}) do
    unless muted do
      IO.puts(message)
    end
  end
end
