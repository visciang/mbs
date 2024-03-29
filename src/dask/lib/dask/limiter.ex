defmodule Dask.Limiter do
  @moduledoc false

  # "Tricky point" about the limiter waiting_list (queue):
  #
  # When a process join the limiter asking "to wait its turn"
  # the limiter adds the process in FRONT of the queue (waiting_list is a LIFO queue).
  # This behaviour plays nice with the Dask DAG, since it startup the DAG in a reverse
  # topologically sorted order (why: see how it's implemented the Dask DAG ;)
  # So the last job joining the queue, the root job in the DAG, will be the first
  # to be served

  use GenServer
  require Logger

  @type max_concurrency :: nil | pos_integer()

  defmodule State do
    @moduledoc false

    defstruct [:max_concurrency, :running_jobs, :waiting_list]

    @type t :: %__MODULE__{
            max_concurrency: non_neg_integer(),
            running_jobs: %{GenServer.server() => reference()},
            waiting_list: [{term(), GenServer.from()}]
          }
  end

  @spec start_link(max_concurrency()) :: GenServer.on_start()
  def start_link(max_concurrency) do
    if max_concurrency == nil do
      {:ok, nil}
    else
      GenServer.start_link(__MODULE__, [max_concurrency])
    end
  end

  @spec wait_my_turn(pid(), term()) :: :ok
  def wait_my_turn(limiter, name \\ nil) do
    if limiter == nil do
      :ok
    else
      GenServer.call(limiter, {:wait_my_turn, name}, :infinity)
    end
  end

  @spec stats(pid()) :: [running: non_neg_integer(), waiting: non_neg_integer()]
  def stats(limiter) do
    GenServer.call(limiter, :stats, :infinity)
  end

  @impl true
  @spec init([non_neg_integer()]) :: {:ok, State.t()}
  def init([max_concurrency]) do
    {:ok, %State{max_concurrency: max_concurrency, running_jobs: %{}, waiting_list: []}}
  end

  @impl true
  def handle_call({:wait_my_turn, name}, {process, _} = from, %State{} = state) do
    Logger.debug("[process=#{inspect(process)}] (#{inspect(name)}) wait_my_turn #{inspect(state, pretty: true)}")

    if map_size(state.running_jobs) == state.max_concurrency do
      Logger.debug(
        "[process=#{inspect(process)}] reached max_concurrency=#{state.max_concurrency}, adding process to the waiting list"
      )

      state = put_in(state.waiting_list, [{name, from} | state.waiting_list])
      {:noreply, state}
    else
      monitor = Process.monitor(process)

      state = put_in(state.running_jobs[process], monitor)
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, %State{} = state) do
    {:reply, [running: map_size(state.running_jobs), waiting: length(state.waiting_list)], state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, process, _reason}, %State{} = state) do
    Logger.debug("[process=#{inspect(process)}] job_end #{inspect(state, pretty: true)}")

    {_, state} = pop_in(state.running_jobs[process])

    state =
      if state.waiting_list != [] do
        [{waiting_job_name, waiting_job} | waiting_list] = state.waiting_list
        GenServer.reply(waiting_job, :ok)

        {waiting_process, _} = waiting_job
        Logger.debug("[process=#{inspect(waiting_process)}] (#{inspect(waiting_job_name)}) it's your turn")

        state = put_in(state.waiting_list, waiting_list)

        monitor = Process.monitor(waiting_process)
        put_in(state.running_jobs[waiting_process], monitor)
      else
        state
      end

    {:noreply, state}
  end
end
