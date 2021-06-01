defmodule Knx.Knxnetip.CEMIFrame do
  defstruct message_code: nil,
            frame_type: nil,
            repeat: nil,
            prio: nil,
            addr_t: nil,
            hops: nil,
            eff: nil,
            src: nil,
            dest: nil,
            len: nil,
            data: <<>>
end
