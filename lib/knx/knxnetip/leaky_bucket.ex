defmodule Knx.KnxnetIp.LeakyBucket do
  # TODO ? credit https://akoutmos.com/post/rate-limiting-with-genservers/

  use GenServer

  require Logger

  def start_link(
        max_queue_size: max_queue_size,
        queue_poll_rate: queue_poll_rate,
        pop_fun: pop_fun
      ) do
    GenServer.start_link(__MODULE__, {max_queue_size, queue_poll_rate, pop_fun}, name: __MODULE__)
  end

  @impl true
  def init({max_queue_size, queue_poll_rate, pop_fun}) do
    state = %{
      queue: :queue.new(),
      queue_size: 0,
      max_queue_size: max_queue_size,
      queue_poll_rate: queue_poll_rate,
      pop_fun: pop_fun,
      send_after_ref: nil
    }

    {:ok, state, {:continue, :initial_timer}}
  end

  # Interface Functions --------------------------------------------------------

  def enqueue(object) do
    GenServer.call(__MODULE__, {:enqueue, object})
  end

  def delay(delay_time) do
    GenServer.cast(__MODULE__, {:delay, delay_time})
  end

  # Server Callback Functions --------------------------------------------------

  @impl true
  def handle_continue(:initial_timer, %{queue_poll_rate: queue_poll_rate} = state) do
    {:noreply, %{state | send_after_ref: schedule_timer(queue_poll_rate)}}
  end

  @impl true
  def handle_call(
        {:enqueue, _object},
        _,
        %{queue_size: max_queue_size, max_queue_size: max_queue_size} = state
      ) do
    {:reply, :queue_overflow, state}
  end

  def handle_call({:enqueue, object}, _, %{queue: queue, queue_size: queue_size} = state) do
    # :logger.debug(
    #   "[D: #{Process.get(:cache_id)}] routing: enqueue cemi frame #{inspect(object)}"
    # )

    queue = :queue.in(object, queue)
    queue_size = queue_size + 1

    {:reply, queue_size, %{state | queue: queue, queue_size: queue_size}}
  end

  @impl true
  def handle_cast({:delay, delay_time}, %{send_after_ref: send_after_ref} = state) do
    if Process.read_timer(send_after_ref) > delay_time do
      {:noreply, state}
    else
      Process.cancel_timer(send_after_ref)
      {:noreply, %{state | send_after_ref: schedule_timer(delay_time)}}
    end
  end

  @impl true
  def handle_info(:pop, %{queue_size: 0, queue_poll_rate: queue_poll_rate} = state) do
    {:noreply, %{state | send_after_ref: schedule_timer(queue_poll_rate)}}
  end

  def handle_info(
        :pop,
        %{
          queue_size: queue_size,
          queue_poll_rate: queue_poll_rate,
          queue: queue,
          pop_fun: pop_fun
        } = state
      ) do
    {{:value, object}, new_queue} = :queue.out(queue)

    # :logger.debug("routing: pop frame from queue #{inspect(object)}")

    # Shell.Server.dispatch(nil, object)
    pop_fun.(object)

    {:noreply,
     %{
       state
       | queue: new_queue,
         queue_size: queue_size - 1,
         send_after_ref: schedule_timer(queue_poll_rate)
     }}
  end

  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp schedule_timer(queue_poll_rate) do
    Process.send_after(self(), :pop, queue_poll_rate)
  end
end
