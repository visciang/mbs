defmodule Workflow.Limiter do
  @moduledoc false

  use GenServer
  require Logger

  @type max_concurrency :: nil | pos_integer()

  defmodule State do
    @moduledoc false

    defstruct [:max_concurrency, :running_jobs, :waiting_list]
  end

  @spec start_link(max_concurrency()) :: GenServer.on_start()
  def start_link(max_concurrency) do
    if max_concurrency == nil do
      {:ok, nil}
    else
      GenServer.start_link(__MODULE__, [max_concurrency])
    end
  end

  @spec wait_my_turn(pid()) :: :ok
  def wait_my_turn(limiter) do
    if limiter == nil do
      :ok
    else
      GenServer.call(limiter, :wait_my_turn, :infinity)
    end
  end

  @spec stats(pid()) :: [running: non_neg_integer(), waiting: non_neg_integer()]
  def stats(limiter) do
    GenServer.call(limiter, :stats)
  end

  @impl true
  def init([max_concurrency]) do
    {:ok, %State{max_concurrency: max_concurrency, running_jobs: %{}, waiting_list: []}}
  end

  @impl true
  def handle_call(:wait_my_turn, {process, _} = from, %State{} = state) do
    Logger.debug("[process=#{inspect(process)}] wait_my_turn #{inspect(state, pretty: true)}")

    if map_size(state.running_jobs) == state.max_concurrency do
      Logger.debug(
        "[process=#{inspect(process)}] reached max_concurrency=#{state.max_concurrency}, adding process to the waiting list"
      )

      state = put_in(state.waiting_list, [from | state.waiting_list])
      {:noreply, state}
    else
      monitor = Process.monitor(process)

      state = put_in(state.running_jobs, Map.put(state.running_jobs, process, monitor))
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

    state = put_in(state.running_jobs, Map.delete(state.running_jobs, process))

    state =
      if state.waiting_list != [] do
        [waiting_job | waiting_list] = state.waiting_list
        GenServer.reply(waiting_job, :ok)

        {waiting_process, _} = waiting_job
        Logger.debug("[process=#{inspect(waiting_process)}] it's your turn")

        put_in(state.waiting_list, waiting_list)
      else
        state
      end

    {:noreply, state}
  end
end
