defmodule Knx.State.GoServer do
  defstruct values: %{},
            deferred: [],
            impulses: [],
            transmitting: false
end

defmodule Knx.State do
  @derive {Inspect, only: [:addr, :c_addr, :handler]}

  defstruct addr: nil,
            max_apdu_length: 15,
            verify: false,
            # tlsm
            c_addr: nil,
            s_seq: 0,
            r_seq: 0,
            rep: 0,
            handler: :closed,
            stored_frame: nil,
            deferred_frames: [],
            # auth
            access_lvl: 0,
            auth: %Knx.Auth{},
            # nl
            hops: 6,
            go_server: %Knx.State.GoServer{},
            # shell
            driver_pid: nil,
            timer_pid: nil,
            connected: false,
            api_expect: %Knx.Api{},   
            api_callback: nil,
            api_timer: nil,
            api_result: [],
            # TODO evtl raus aus state, wird nur in handle_impulses gebraucht
            pending_effects: []

  def update_from_device_props(%__MODULE__{driver_pid: driver_pid} = state, device_props) do
    addr = Knx.Ail.Device.get_address(device_props)
    if driver_pid, do: send(driver_pid, {:set_addr, addr})

    %__MODULE__{
      state
      | addr: Knx.Ail.Device.get_address(device_props),
        max_apdu_length: Knx.Ail.Device.get_max_apdu_length(device_props),
        verify: Knx.Ail.Device.verify?(device_props)
    }
  end
end
