defmodule Knx.KnxnetIp.FrameQueue do
  # TODO ? credit https://akoutmos.com/post/rate-limiting-with-genservers/
  # !info: this is no longer a leaky bucket - rather a regular queue
  use GenServer

  require Logger

  @me __MODULE__

  def start_link(opts) do
    GenServer.start_link(@me, opts, name: @me)
  end

  @impl true
  def init(_) do
    state = %{queue: :queue.new(), queue_size: 0}

    {:ok, state}
  end

  # Interface Functions --------------------------------------------------------

  def enqueue(knx_frame) do
    GenServer.cast(@me, {:enqueue, knx_frame})
  end

  def pop() do
    GenServer.call(@me, {:pop})
  end

  # Server Callback Functions --------------------------------------------------

  @impl true
  def handle_call({:enqueue, knx_frame}, _, state) do
    new_queue = :queue.in(knx_frame, state.queue)

    {:reply, state.queue_size, %{state | queue: new_queue, queue_size: state.queue_size + 1}}
  end

  @impl true
  def handle_call({:pop}, _, %{queue_size: 0} = state) do
    {:reply, :empty_queue, state}
  end

  def handle_call({:pop}, _, state) do
    {{:value, knx_frame}, new_queue} = :queue.out(state.queue)

    {:reply, knx_frame, %{state | queue: new_queue, queue_size: state.queue_size - 1}}
  end

  # def handle_info({ref, _result}, state) do
  #   Process.demonitor(ref, [:flush])

  #   {:noreply, state}
  # end

  # def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
  #   {:noreply, state}
  # end
end
