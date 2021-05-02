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
            auth: nil,
            # nl
            hops: 6,
            go_server: %Knx.State.GoServer{},
            # TODO evtl raus aus state, wird nur in handle_impulses gebraucht
            pending_effects: []

  def update_from_cache(state) do
    device_props = Cache.get({:objects, 0})

    %__MODULE__{
      state
      | addr: Knx.Ail.Device.get_address(device_props),
        max_apdu_length: Knx.Ail.Device.get_max_apdu_length(device_props),
        verify: Knx.Ail.Device.verify?(device_props)
    }
  end
end

