defmodule Knx.KnxnetIp.Queue do
  use GenServer

  require Logger

  def start_link(name: name, max_queue_size: max_queue_size) do
    GenServer.start_link(__MODULE__, %{max_queue_size: max_queue_size}, name: name)
  end

  @impl true
  def init(%{max_queue_size: max_queue_size}) do
    state = %{
      queue: :queue.new(),
      queue_size: 0,
      max_queue_size: max_queue_size
    }

    {:ok, state}
  end

  # Interface Functions --------------------------------------------------------

  def enqueue(pid, object) do
    GenServer.call(pid, {:enqueue, object})
  end

  def get_size(pid) do
    GenServer.call(pid, {:get_size})
  end

  def pop(pid) do
    GenServer.call(pid, {:pop})
  end

  # Server Callback Functions --------------------------------------------------

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

    {:reply, :ok, %{state | queue: queue, queue_size: queue_size}}
  end

  @impl true
  def handle_call(
        {:get_size},
        _,
        %{queue_size: queue_size} = state
      ) do
    {:reply, queue_size, state}
  end

  # @impl true
  # def handle_call({:pop}, _, %{queue: queue, queue_size: queue_size} = state) do
  #   case :queue.out(queue) do
  #     {{:value, object}, queue} ->
  #       queue_size = queue_size - 1
  #       {:reply, {:object, object}, %{state | queue: queue, queue_size: queue_size}}

  #     {:empty, queue} ->
  #       {:reply, :empty, %{state | queue: queue, queue_size: queue_size}}
  #   end
  # end

  @impl true
  def handle_call({:pop}, _, %{queue: queue, queue_size: queue_size} = state) do
    case :queue.out(queue) do
      {{:value, object}, queue} ->
        Shell.Server.dispatch(:server, {:knip, :from_ip, object})
        queue_size = queue_size - 1
        {:reply, {:object, object}, %{state | queue: queue, queue_size: queue_size}}

      {:empty, queue} ->
        {:reply, :empty, %{state | queue: queue, queue_size: queue_size}}
    end
  end
end
