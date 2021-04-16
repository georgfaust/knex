defmodule Knx.State do
  @type t :: %__MODULE__{
          addr: non_neg_integer() | nil,
          c_addr: non_neg_integer() | nil,
          s_seq: non_neg_integer(),
          r_seq: non_neg_integer(),
          rep: non_neg_integer(),
          handler: Knx.Stack.Tlsm.Sm.handler_t(),
          stored_frame: Knx.Frame.t() | nil,
          deferred_frames: [Knx.Frame.t()],
          timer_pid: pid() | nil,
          access_lvl: non_neg_integer(),
          objects: map(),
          pending_effects: [Knx.impulse_t()],
          hops: any(),
          addr_tab: any(),
          auth: KNX.Auth.t()
        }

  @derive {Inspect, only: [:addr, :c_addr, :handler, :pending_effects]}
  defstruct addr: nil,
            c_addr: nil,
            s_seq: 0,
            r_seq: 0,
            rep: 0,
            handler: :closed,
            stored_frame: nil,
            deferred_frames: [],
            timer_pid: nil,
            access_lvl: 0,
            objects: %{},
            pending_effects: [],
            hops: 6,
            addr_tab: nil,
            auth: nil
end
