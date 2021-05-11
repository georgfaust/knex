defmodule Shell.Server do
  use GenServer

  alias Knx
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  @me __MODULE__
  # @timer_config %{{:tlsm, :ack} => 3000, {:tlsm, :connection} => 6000}

  def start_link(name: name, objects: objects, mem: mem, driver_mod: driver_mod) do
    GenServer.start_link(@me, {objects, mem, driver_mod}, name: name)
  end

  def dispatch(pid, impulse) do
    GenServer.cast(pid, impulse)
  end

  def set_prog_mode(pid, prog_mode) do
    GenServer.cast(pid, {:prog_mode, prog_mode})
  end

  def api_call(pid, impulse, expect) do
    dispatch(pid, impulse)
    GenServer.call(pid, {:api_expect, expect})
  end

  def cache_get(pid, key) do
    GenServer.call(pid, {:cache_get, key})
  end

  # --------------------------------------------------------------------

  @impl GenServer
  def init({objects, mem, driver_mod}) do
    serial = Knx.Ail.Property.read_prop_value(objects[0], :pid_serial)

    Process.put(:cache_id, serial)

    Cache.start_link(%{
      {:objects, 0} => objects[0],
      {:objects, 1} => objects[1],
      {:objects, 2} => objects[2],
      {:objects, 3} => objects[3],
      :mem => mem,
      :go_values => %{}
    })

    state = S.update_from_device_props(%S{}, objects[0])

    Knx.Ail.Table.load(Knx.Ail.AddrTab)
    Knx.Ail.Table.load(Knx.Ail.AssocTab)
    Knx.Ail.Table.load(Knx.Ail.GoTab)

    :logger.info("[D: #{Process.get(:cache_id)}] NEW. addr: #{state.addr}")

    # IO.inspect(Cache.get({:objects, 0}), label: :device)
    :logger.debug("[D: #{Process.get(:cache_id)}] addr_tab: #{inspect(Cache.get(:addr_tab))}")
    :logger.debug("[D: #{Process.get(:cache_id)}] assoc_tab: #{inspect(Cache.get(:assoc_tab))}")
    # IO.inspect(Cache.get(:go_tab), label: :go_tab)

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

  def handle_call({:api_expect, %Knx.Api{timeout_ms: timeout} = expect}, from, state) do
    {:ok, pid} = :timer.send_after(timeout, :api_timeout)
    {:noreply, %S{state | api_expect: expect, api_callback: from, api_timer: pid}}
  end

  @impl GenServer
  def handle_cast({:bus_info, :connected}, %S{} = state) do
    :logger.info("[D: #{Process.get(:cache_id)}] connected")
    {:noreply, %S{state | connected: true}}
  end

  def handle_cast({_layer, _prim, _data} = impulse, %S{} = state) do
    :logger.info("[D: #{Process.get(:cache_id)}] [<< imp] #{inspect(impulse)}")
    {:noreply, handle_impulse(impulse, state)}
  end

  def handle_cast({:prog_mode, prog_mode}, state) do
    # Device.set(&Device.set_prog_mode(&1, prog_mode))
    # ---
    # def set(setter) do
    #   props = Cache.get({:objects, 0})
    #   props = setter.(props)
    #   Cache.put({:objects, 0}, props)
    # end
    props = Cache.get({:objects, 0})
    props = Knx.Ail.Device.set_prog_mode(props, prog_mode)
    # IO.inspect(props)
    Cache.put({:objects, 0}, props)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {:mgmt, prim, %F{apci: apci, ok?: ok?} = frame},
        %S{
          api_expect: %Knx.Api{apci: exp_apci, prim: exp_prim, multi: multi, take: take},
          api_callback: api_callback,
          api_timer: timer_pid,
          api_result: api_result
        } = state
      ) do
    if prim == exp_prim and apci == exp_apci do
      if multi do
        {:noreply, %S{state | api_result: [Map.take(frame, take) | api_result]}}
      else
        call_done(timer_pid, api_callback, {:api_result, Map.take(frame, take)}, state)
      end
    else
      if apci == :a_discon and api_callback do
        call_done(
          timer_pid,
          api_callback,
          {if(ok? == false, do: :negative_lcon, else: :pdu), :a_discon, exp_apci},
          state
        )
      else
        {:noreply, state}
      end
    end
  end

  def handle_info(
        :api_timeout,
        %S{
          api_expect: %Knx.Api{apci: apci, multi: multi},
          api_callback: api_callback,
          api_result: api_result
        } = state
      ) do
    result =
      if multi do
        {:api_multi_result, apci, api_result}
      else
        {:error, apci, :no_resp}
      end

    GenServer.reply(api_callback, result)

    {:noreply,
     %S{state | api_expect: %Knx.Api{}, api_callback: nil, api_timer: nil, api_result: []}}
  end

  # --------------------------------------------------------------------

  defp handle_impulse({target, _, _} = impulse, %S{} = state) do
    handle =
      Map.fetch!(
        %{
          dl: fn impulse -> Knx.handle_impulses(state, [impulse]) end,
          tlsm: fn impulse -> Knx.handle_impulses(state, [impulse]) end,
          al: fn impulse -> Knx.handle_impulses(state, [impulse]) end,
          go: fn impulse -> Knx.handle_impulses(state, [impulse]) end
        },
        target
      )

    {effects, state} = handle.(impulse)
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

  defp call_done(timer_pid, api_callback, result, state) do
    :timer.cancel(timer_pid)
    GenServer.reply(api_callback, result)

    {:noreply,
     %S{state | api_expect: %Knx.Api{}, api_callback: nil, api_timer: nil, api_result: []}}
  end
end
