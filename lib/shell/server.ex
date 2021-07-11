defmodule Shell.Server do
  use GenServer, restart: :transient

  alias Knx
  alias Knx.State, as: S
  # alias Knx.Frame, as: F

  @me __MODULE__
  # @timer_config %{{:tlsm, :ack} => 3000, {:tlsm, :connection} => 6000}

  def start_link(name: _name, objects: objects, mem: mem, driver_mod: driver_mod) do
    GenServer.start_link(@me, {objects, mem, driver_mod}, name: __MODULE__)
  end

  # def stop(name) do
  #   GenServer.cast(name, :stop)
  # end

  def dispatch(_pid, impulse) do
    GenServer.cast(__MODULE__, impulse)
  end

  def set_prog_mode(_pid, prog_mode) do
    GenServer.cast(__MODULE__, {:prog_mode, prog_mode})
  end

  def cache_get(_pid, key) do
    GenServer.call(__MODULE__, {:cache_get, key})
  end

  # --------------------------------------------------------------------

  @impl GenServer
  def init({objects, mem, driver_mod}) do
    serial = Knx.Ail.Property.read_prop_value(objects[:device], :serial)

    Process.put(:cache_id, serial)

    Cache.start_link(%{
      objects: objects,
      mem: mem,
      go_values: %{}
    })

    state = S.update_from_device_props(%S{}, objects[:device])

    Knx.Ail.Table.load(Knx.Ail.AddrTab)
    Knx.Ail.Table.load(Knx.Ail.AssocTab)
    Knx.Ail.Table.load(Knx.Ail.GoTab)

    :logger.info("[D: #{Process.get(:cache_id)}] NEW. addr: #{state.addr}")
    :logger.debug("[D: #{Process.get(:cache_id)}] addr_tab: #{inspect(Cache.get(:addr_tab))}")
    :logger.debug("[D: #{Process.get(:cache_id)}] assoc_tab: #{inspect(Cache.get(:assoc_tab))}")
    :logger.debug("[D: #{Process.get(:cache_id)}] go_tab: #{inspect(Cache.get(:go_tab))}")

    {:ok, driver_pid} = driver_mod.start_link(addr: state.addr)
    # {:ok, timer_pid} = Shell.Timer.start_link({self(), @timer_config})
    timer_pid = nil

    {:ok, %S{state | driver_pid: driver_pid, timer_pid: timer_pid}}
  end

  @impl GenServer
  def handle_call({:cache_get, key}, _from, state) do
    value = Cache.get(key)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_cast({:bus_info, :connected}, %S{} = state) do
    :logger.info("[D: #{Process.get(:cache_id)}] connected")
    {:noreply, %S{state | connected: true}}
  end

  @impl GenServer
  def handle_cast({_layer, _prim, _data} = impulse, %S{} = state) do
    :logger.info("[D: #{Process.get(:cache_id)}] [<< imp] #{inspect(impulse)}")
    {:noreply, handle_impulse(impulse, state)}
  end

  @impl GenServer
  def handle_cast({:prog_mode, prog_mode}, state) do
    # Device.set(&Device.set_prog_mode(&1, prog_mode))
    # ---
    # def set(setter) do
    #   props = Cache.get_obj ...
    #   props = setter.(props)
    #   Cache.put_obj(..., props)
    # end
    props = Cache.get_obj(:device)
    props = Knx.Ail.Device.set_prog_mode(props, prog_mode)
    Cache.put_obj(:device, props)
    {:noreply, state}
  end

  # --------------------------------------------------------------------

  defp handle_impulse({_, _, _} = impulse, %S{} = state) do
    {effects, state} = Knx.handle_impulses(state, [impulse])
    Enum.each(effects, fn effect -> handle_effect(effect, state) end)
    state
  end

  defp handle_effect(
         {target, _, _} = effect,
         %S{driver_pid: driver_pid, timer_pid: _timer_pid}
       ) do
    handle =
      Map.fetch!(
        %{
          # add interface function for timer?
          # timer: fn effect -> send(timer_pid, effect) end,
          timer: fn effect -> log_effect(effect) end,
          driver: fn effect -> send(driver_pid, effect) end,
          mgmt: fn effect -> send(self(), effect) end,
          app: fn effect -> log_effect(effect) end,
          logger: fn effect -> log_effect(effect) end
        },
        target
      )

    handle.(effect)
  end

  defp log_effect(effect) do
    :logger.info("[D: #{Process.get(:cache_id)}] [eff >>] #{inspect(effect)}")
  end
end
