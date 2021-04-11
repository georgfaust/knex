defmodule Knx.Timer do
  defstruct timeouts: %{},
            timer_pids: %{},
            callback_pid: nil

  use GenServer

  @type signal_t :: :timeout | :stop | :start | :restart
  @type instance_t :: :ack | :connection

  @type impulse_t :: {Knx.Stack.layer_t() | :timer, signal_t(), instance_t()}


  # --------------------------------------------------------------------
  # Client API

  def start_link({callback_pid, timeouts}) do
    GenServer.start_link(__MODULE__, {callback_pid, timeouts})
  end

  def handle(pid, impulse, _) do
    GenServer.cast(pid, impulse)
    []
  end

  # --------------------------------------------------------------------
  # GenServer API

  def init({callback_pid, timeouts}) do
    {
      :ok,
      %__MODULE__{callback_pid: callback_pid, timeouts: timeouts}
    }
  end

  def handle_cast({:timer, command, timer}, %__MODULE__{} = state) do
    state =
      case command do
        :start -> start(state, timer)
        :restart -> restart(state, timer)
        :stop -> stop(state, timer)
      end

    {:noreply, state}
  end

  def handle_info(
        {:timeout, {target, timer}},
        %__MODULE__{callback_pid: callback_pid} = state
      ) do
    send(callback_pid, {target, :timeout, timer})
    {:noreply, state}
  end

  # --------------------------------------------------------------------

  defp stop(%__MODULE__{timer_pids: timer_pids} = state, timer) do
    :timer.cancel(timer_pids[timer])
    %__MODULE__{state | timer_pids: Map.put(timer_pids, timer, nil)}
  end

  defp start(%__MODULE__{timer_pids: timer_pids, timeouts: timeouts} = state, timer) do
    {:ok, pid} = :timer.send_after(timeouts[timer], {:timeout, timer})
    %__MODULE__{state | timer_pids: Map.put(timer_pids, timer, pid)}
  end

  defp restart(%__MODULE__{} = state, timer) do
    state |> stop(timer) |> start(timer)
  end
end
