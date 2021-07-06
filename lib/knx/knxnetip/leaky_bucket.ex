defmodule Knx.KnxnetIp.LeakyBucket do
  # TODO ? credit https://akoutmos.com/post/rate-limiting-with-genservers/

  use GenServer

  require Logger

  def start_link(%{name: name} = opts) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(%{
        queue_type: queue_type,
        queue_size: queue_size,
        max_queue_size: max_queue_size,
        queue_poll_rate: queue_poll_rate
      }) do
    state = %{
      queue: :queue.new(),
      queue_type: queue_type,
      queue_size: queue_size,
      max_queue_size: max_queue_size,
      queue_poll_rate: queue_poll_rate,
      send_after_ref: nil
    }

    {:ok, state, {:continue, :initial_timer}}
  end

  # Interface Functions --------------------------------------------------------

  def enqueue(pid, object) do
    GenServer.call(pid, {:enqueue, object})
  end

  def delay(pid, delay_time) do
    GenServer.cast(pid, {:delay, delay_time})
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
    # queue is full: stack shall send routing lost message
    {:reply, :queue_overflow, state}
  end

  def handle_call({:enqueue, object}, _, %{queue: queue, queue_size: queue_size} = state) do
    new_queue = :queue.in(object, queue)
    new_queue_size = queue_size + 1

    # report back new queue size, allowing stack to react via flow control (routing busy frame)
    {:reply, new_queue_size, %{state | queue: new_queue, queue_size: new_queue_size}}
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
  def handle_info({:pop}, %{queue_size: 0, queue_poll_rate: queue_poll_rate} = state) do
    {:no_reply, %{state | send_after_ref: schedule_timer(queue_poll_rate)}}
  end

  def handle_info(
        {:pop},
        %{
          queue_size: queue_size,
          queue_poll_rate: queue_poll_rate,
          queue: queue,
          queue_type: queue_type
        } = state
      ) do
    {{:value, object}, new_queue} = :queue.out(queue)

    case queue_type do
      :knx_queue ->
        # object: %F-Struct
        Shell.Server.dispatch(:server, {:knip, :from_knx, object})

      :ip_queue ->
        # object: {%Ep-Struct (of ip src), %F-Struct}
        Shell.Server.dispatch(:server, {:knip, :from_ip, object})
    end

    {:no_reply,
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
