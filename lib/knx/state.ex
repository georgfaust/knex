defmodule Knx.State do
  @derive {Inspect, only: [:addr, :c_addr, :handler, :pending_effects]}
  defstruct addr: nil,
            c_addr: nil,
            s_seq: 0,
            r_seq: 0,
            rep: 0,
            handler: :closed,
            stored_frame: nil,
            deferred_frames: [],
            # now part of shell state
            timer_pid: nil,
            access_lvl: 0,
            objects: %{},
            pending_effects: [],
            hops: 6,
            auth: nil,
            go_server: %Knx.Ail.GoServer{},
            mem: <<>>
end
