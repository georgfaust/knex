defmodule Knx.KnxnetIp.LeakyBucket do
  use GenServer
  require Logger

  @moduledoc """
  The LeakyBucket module provides a GenServer that implements the leaky bucket algorithm.

  Since KNXnet/Ip frames cannot be sent on the network with an arbitrary rate (routers could overflow),
  the leaky bucket algorithm is used to restrict the sending rate.

  Credit: inspired by https://akoutmos.com/post/rate-limiting-with-genservers/
  """

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

  @doc """
  Initially schedules the timer to the queue poll rate.
  """
  @impl true
  def handle_continue(:initial_timer, %{queue_poll_rate: queue_poll_rate} = state) do
    {:noreply, %{state | send_after_ref: schedule_timer(queue_poll_rate)}}
  end

  @doc """
  Enqueues the object.

  If max queue size is reached, the caller is informed about the overflow.
  """
  @impl true
  def handle_call(
        {:enqueue, _object},
        _,
        %{queue_size: max_queue_size, max_queue_size: max_queue_size} = state
      ) do
    {:reply, :queue_overflow, state}
  end

  def handle_call({:enqueue, object}, _, %{queue: queue, queue_size: queue_size} = state) do
    queue = :queue.in(object, queue)
    queue_size = queue_size + 1

    {:reply, queue_size, %{state | queue: queue, queue_size: queue_size}}
  end

  @impl true
  @doc """
  Delays the timer as long as the timeout of the current timer is closer than the delay.
  """
  def handle_cast({:delay, delay_time}, %{send_after_ref: send_after_ref} = state) do
    if Process.read_timer(send_after_ref) > delay_time do
      {:noreply, state}
    else
      Process.cancel_timer(send_after_ref)
      {:noreply, %{state | send_after_ref: schedule_timer(delay_time)}}
    end
  end

  @impl true
  @doc """
  Pops one element from the queue (FIFO).
  """
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

    pop_fun.(object)

    {:noreply,
     %{
       state
       | queue: new_queue,
         queue_size: queue_size - 1,
         send_after_ref: schedule_timer(queue_poll_rate)
     }}
  end

  defp schedule_timer(queue_poll_rate) do
    Process.send_after(self(), :pop, queue_poll_rate)
  end
end
