defmodule Knx.KnxnetIp.LeakyBucket do
  # TODO ? credit https://akoutmos.com/post/rate-limiting-with-genservers/

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(%{queue_type: queue_type, queue_poll_rate: queue_poll_rate}) do
    state = %{
      queue: :queue.new(),
      queue_type: queue_type,
      queue_size: 0,
      queue_poll_rate: queue_poll_rate,
      send_after_ref: nil
    }

    {:ok, state, {:continue, :initial_timer}}
  end

  # Interface Functions --------------------------------------------------------

  def enqueue(pid, knx_frame) do
    GenServer.call(pid, {:enqueue, knx_frame})
  end

  def delay(pid, delay_time) do
    GenServer.cast(pid, {:delay, delay_time})
  end

  # Server Callback Functions --------------------------------------------------

  @impl true
  def handle_continue(:initial_timer, state) do
    {:noreply, %{state | send_after_ref: schedule_timer(state.queue_poll_rate)}}
  end

  @impl true
  def handle_call({:enqueue, knx_frame}, _, state) do
    new_queue = :queue.in(knx_frame, state.queue)
    new_queue_size = state.queue_size + 1

    # report back new queue size, allowing stack to react via flow control
    {:reply, new_queue_size, %{state | queue: new_queue, queue_size: new_queue_size}}
  end

  @impl true
  def handle_cast({:delay, delay_time}, state) do
    Process.cancel_timer(state.send_after_ref)

    {:noreply, %{state | send_after_ref: schedule_timer(delay_time)}}
  end

  @impl true
  def handle_info({:pop}, %{queue_size: 0} = state) do
    {:no_reply, %{state | send_after_ref: schedule_timer(state.request_queue_poll_rate)}}
  end

  def handle_info({:pop}, state) do
    {{:value, knx_frame}, new_queue} = :queue.out(state.queue)

    case state.queue_type do
      :knx_queue ->
        Shell.Server.dispatch(:server, {:ip, :from_knx, knx_frame})

      :ip_queue ->
        Shell.Server.dispatch(:server, {:ip, :from_ip, knx_frame})
    end

    {:no_reply,
     %{
       state
       | queue: new_queue,
         queue_size: state.queue_size - 1,
         send_after_ref: schedule_timer(state.queue_poll_rate)
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
