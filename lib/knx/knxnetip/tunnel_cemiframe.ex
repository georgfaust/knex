defmodule Knx.Knxnetip.TunnelCemiFrame do
  defstruct message_code: nil,
            frame_type: nil,
            repeat: nil,
            prio: nil,
            addr_t: nil,
            hops: nil,
            eff: 0,
            src: nil,
            dest: nil,
            len: nil,
            data: <<>>
end
