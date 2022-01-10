defmodule MBS.CLI.Reporter do
  @moduledoc false

  use GenServer

  alias MBS.CLI.Reporter.{Report, Status}
  alias MBS.Const

  require MBS.CLI.Reporter.Status

  @name __MODULE__

  @time_unit :millisecond
  @time_unit_scale 0.001

  defmodule State do
    @moduledoc false

    @enforce_keys [:logs_to_file, :logs_dir, :job_id_to_log_file, :start_time, :success_jobs, :failed_jobs]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            logs_to_file: boolean(),
            logs_dir: Path.t(),
            job_id_to_log_file: %{String.t() => File.io_device()},
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
    GenServer.call(@name, {:stop, workflow_status}, :infinity)
  end

  @spec mute(boolean()) :: :ok
  def mute(status) do
    GenServer.call(@name, {:mute, status}, :infinity)
  end

  @spec logs(boolean()) :: :ok
  def logs(enabled) do
    GenServer.call(@name, {:logs, enabled}, :infinity)
  end

  @spec logs_to_file(boolean()) :: :ok
  def logs_to_file(enabled) do
    GenServer.call(@name, {:logs_to_file, enabled}, :infinity)
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
      GenServer.call(
        @name,
        %Report{job_id: job_id, status: status, description: description, elapsed: elapsed},
        :infinity
      )
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

    {:ok,
     %State{
       logs_to_file: false,
       logs_dir: Path.join(Const.logs_dir(), to_string(DateTime.utc_now())),
       job_id_to_log_file: %{},
       start_time: start_time,
       success_jobs: [],
       failed_jobs: []
     }}
  end

  @impl true
  def handle_call(
        %Report{job_id: job_id, status: status, description: description, elapsed: elapsed},
        _from,
        %State{} = state
      ) do
    {state, log_file_} = log_file(state, job_id)
    state = track_jobs(job_id, status, state)

    duration = if elapsed != nil, do: " (#{delta_time_string(elapsed)}) ", else: ""
    description = if description != nil, do: "| #{description}", else: ""
    {status_icon, status_info} = status_icon_info(status)

    job_id = if status == Status.log(), do: IO.ANSI.format([:yellow, job_id]), else: job_id

    log_puts(
      log_file_,
      IO.ANSI.format([status_icon, " - ", :bright, job_id, :normal, "  ", duration, " ", :faint, description])
    )

    if status_info, do: log_puts(log_file_, "  - #{status_info}")

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
  def handle_call({:logs_to_file, enabled}, _from, %State{logs_dir: logs_dir} = state) do
    if enabled, do: File.mkdir_p!(logs_dir)
    {:reply, :ok, put_in(state.logs_to_file, enabled)}
  end

  @impl true
  def handle_call(
        {:stop, reason},
        _from,
        %State{
          logs_to_file: logs_to_file,
          logs_dir: logs_dir,
          job_id_to_log_file: job_id_to_log_file,
          start_time: start_time,
          success_jobs: success_jobs,
          failed_jobs: failed_jobs
        } = state
      ) do
    end_time = time()

    if logs_to_file do
      log_stdout_puts("\nLogs directory: #{logs_dir}")

      job_id_to_log_file
      |> Map.values()
      |> Enum.each(&File.close/1)
    end

    end_message =
      case reason do
        :ok -> IO.ANSI.format([:green, "Completed (#{length(success_jobs)} jobs)"])
        :error -> IO.ANSI.format([:red, "Failed jobs:", :normal, Enum.map(Enum.sort(failed_jobs), &"\n- #{&1}"), "\n"])
        :timeout -> IO.ANSI.format([:red, "Timeout"])
      end

    duration = delta_time_string(end_time - start_time)

    log_stdout_puts("\n#{end_message} (#{duration})")

    {:stop, :normal, :ok, state}
  end

  @spec track_jobs(String.t(), Status.t(), State.t()) :: State.t()
  defp track_jobs(job_id, status, %State{} = state) do
    case status do
      Status.error(_reason, _stacktrace) -> update_in(state.failed_jobs, &[job_id | &1])
      Status.ok() -> update_in(state.success_jobs, &[job_id | &1])
      Status.uptodate() -> update_in(state.success_jobs, &[job_id | &1])
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
      Status.ok() ->
        {IO.ANSI.format([:green, "✔"]), nil}

      Status.error(reason, stacktrace) ->
        reason_str =
          if is_binary(reason) do
            reason
          else
            inspect(reason)
          end

        reason_str =
          if stacktrace != nil do
            [reason_str, "\n", stacktrace]
          else
            reason_str
          end

        {IO.ANSI.format([:red, "✘"]), reason_str}

      Status.uptodate() ->
        {"✔", nil}

      Status.outdated() ->
        {IO.ANSI.format([:yellow, "!"]), nil}

      Status.timeout() ->
        {"⏰", nil}

      Status.log() ->
        {".", nil}
    end
  end

  @spec log_puts(nil | File.io_device(), IO.chardata()) :: :ok
  defp log_puts(log_file, message) do
    log_stdout_puts(message)

    if log_file != nil do
      IO.write(log_file, message)
      IO.write(log_file, "\n")
    end
  end

  @spec log_stdout_puts(IO.chardata()) :: :ok
  defp log_stdout_puts(message) do
    unless :ets.lookup_element(@name, :muted, 2), do: IO.puts(message)
    :ok
  end

  @spec log_file(State.t(), String.t()) :: {State.t(), nil | File.io_device()}
  defp log_file(%State{logs_to_file: false} = state, _job_id), do: {state, nil}

  defp log_file(%State{job_id_to_log_file: job_id_to_log_file} = state, job_id)
       when is_map_key(job_id_to_log_file, job_id),
       do: {state, job_id_to_log_file[job_id]}

  defp log_file(%State{logs_dir: logs_dir} = state, job_id) do
    file = File.open!(Path.join(logs_dir, "#{job_id}.txt"), [:utf8, :write])
    state = update_in(state.job_id_to_log_file, &Map.put(&1, job_id, file))
    {state, file}
  end
end
