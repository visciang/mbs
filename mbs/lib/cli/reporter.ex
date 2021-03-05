defmodule MBS.CLI.Reporter do
  @moduledoc """
  CLI information reporter
  """
  @time_unit :millisecond
  @time_unit_scale 0.001

  use GenServer

  alias MBS.CLI.Reporter.{Report, Status}
  require MBS.CLI.Reporter.Status

  defstruct [:reporter, :job_id]

  defmodule State do
    @moduledoc false

    defstruct [:start_time]
  end

  def start_link do
    GenServer.start_link(__MODULE__, start_time: time())
  end

  def stop(pid, workflow_status) do
    GenServer.call(pid, {:stop, workflow_status})
  end

  def job_report(pid, job_id, status, description, elapsed) do
    GenServer.cast(pid, %Report{job_id: job_id, status: status, description: description, elapsed: elapsed})
  end

  def time do
    System.monotonic_time(@time_unit)
  end

  @impl true
  def init(start_time: start_time) do
    {:ok, %State{start_time: start_time}}
  end

  @impl true
  def handle_cast(%Report{job_id: job_id, status: status, description: description, elapsed: elapsed}, %State{} = state) do
    {status_icon, status_info} = status_icon_info(status)

    duration = if elapsed != nil, do: " (#{delta_time_string(elapsed)})", else: ""
    description = if description != nil, do: "~ #{description}", else: ""

    IO.puts(
      IO.ANSI.format(
        [status_icon, " - ", :bright, job_id, :normal, "  ", duration, " ", description],
        true
      )
    )

    if status_info, do: IO.puts("  - #{status_info}")

    {:noreply, state}
  end

  @impl true
  def handle_call({:stop, reason}, _from, %State{} = state) do
    end_time = time()

    log_message =
      case reason do
        :ok -> IO.ANSI.format([:green, "Successfully completed"], true)
        :error -> IO.ANSI.format([:red, "Failed"], true)
        :timeout -> IO.ANSI.format([:red, "Timeout"], true)
      end

    duration = delta_time_string(end_time - state.start_time)

    IO.puts("\n#{log_message} (#{duration})")

    {:stop, :normal, :ok, state}
  end

  defp delta_time_string(elapsed) do
    Dask.Utils.seconds_to_compound_duration(elapsed * @time_unit_scale)
  end

  defp status_icon_info(status) do
    case status do
      Status.ok() -> {IO.ANSI.format([:green, "✔"], true), nil}
      Status.error(reason) -> {IO.ANSI.format([:red, "✘"], true), reason}
      Status.uptodate() -> {"✔", nil}
      Status.outdated() -> {IO.ANSI.format([:yellow, "!"], true), nil}
      Status.timeout() -> {"⏰", nil}
      Status.log() -> {".", nil}
    end
  end
end
