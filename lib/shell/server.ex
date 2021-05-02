defmodule Shell.Server do
  use GenServer

  alias Knx
  alias Knx.State, as: S
  alias Shell.State, as: SS

  @me __MODULE__
  # @timer_config %{{:tlsm, :ack} => 3000, {:tlsm, :connection} => 6000}

  def start_link(name: name, objects: objects, mem: mem, driver_mod: driver_mod) do
    GenServer.start_link(@me, {objects, mem, driver_mod}, name: name)
  end

  def dispatch(pid, impulse) do
    GenServer.cast(pid, impulse)
  end

  def to_bus(pid, impulse) do
    GenServer.cast(pid, {:to_bus, impulse})
  end

  # --------------------------------------------------------------------

  @impl GenServer
  def init({objects, mem, driver_mod}) do
    serial = Knx.Ail.Property.read_prop_value(objects[0], :pid_serial)
    subnet_addr = Knx.Ail.Property.read_prop_value(objects[0], :pid_subnet_addr)

    Process.put(:cache_id, serial)

    Cache.start_link(%{
      {:objects, 0} => objects[0],
      {:objects, 1} => objects[1],
      {:objects, 2} => objects[2],
      {:objects, 9} => objects[9],
      :mem => mem,
      :go_values => %{}
    })

    core_state = S.update_from_cache(%S{})

    Knx.Ail.Table.load(Knx.Ail.AddrTab)
    Knx.Ail.Table.load(Knx.Ail.AssocTab)
    Knx.Ail.Table.load(Knx.Ail.GoTab)

    :logger.info("[D: #{Process.get(:cache_id)}] NEW. addr: #{core_state.addr}")

    # IO.inspect(Cache.get({:objects, 0}), label: :device)
    :logger.debug("[D: #{Process.get(:cache_id)}] addr_tab: #{inspect(Cache.get(:addr_tab))}")
    :logger.debug("[D: #{Process.get(:cache_id)}] assoc_tab: #{inspect(Cache.get(:assoc_tab))}")
    # IO.inspect(Cache.get(:go_tab), label: :go_tab)

    {:ok, driver_pid} = driver_mod.start_link(addr: subnet_addr)
    # {:ok, timer_pid} = Shell.Timer.start_link({self(), @timer_config})
    timer_pid = nil

    {
      :ok,
      %SS{
        driver_pid: driver_pid,
        timer_pid: timer_pid,
        serial: serial,
        core_state: core_state
      }
    }
  end

  @impl GenServer
  def handle_cast({:bus_info, :connected}, %SS{} = state) do
    :logger.info("[D: #{Process.get(:cache_id)}] connected")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({_layer, _prim, _data} = impulse, %SS{} = state) do
    :logger.info("[D: #{Process.get(:cache_id)}] [<< imp] #{inspect(impulse)}")
    handle_impulse(impulse, state)
    {:noreply, state}
  end

  # --------------------------------------------------------------------

  defp handle_impulse({target, _, _} = impulse, %SS{core_state: core_state} = shell_state) do
    handle =
      Map.fetch!(
        %{
          dl: fn impulse -> Knx.handle_impulses(core_state, [impulse]) end,
          tlsm: fn impulse -> Knx.handle_impulses(core_state, [impulse]) end,
          al: fn impulse -> Knx.handle_impulses(core_state, [impulse]) end,
          go: fn impulse -> Knx.handle_impulses(core_state, [impulse]) end
        },
        target
      )

    {effects, core_state} = handle.(impulse)
    shell_state = %SS{shell_state | core_state: core_state}
    Enum.each(effects, fn effect -> handle_effect(effect, shell_state) end)
  end

  defp handle_effect({target, _, _} = effect, %SS{driver_pid: driver_pid, timer_pid: _timer_pid}) do
    handle =
      Map.fetch!(
        %{
          # add interface function for timer?
          # timer: fn effect -> send(timer_pid, effect) end,
          timer: fn effect -> log_effect(effect) end,
          driver: fn effect -> send(driver_pid, effect) end,
          user: fn effect -> log_effect(effect) end,
          logger: fn effect -> log_effect(effect) end,
          todo: fn effect -> log_effect(effect) end
        },
        target
      )

    handle.(effect)
  end

  defp log_effect(effect) do
    :logger.info("[D: #{Process.get(:cache_id)}] [eff >>] #{inspect(effect)}")
  end
end
