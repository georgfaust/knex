defmodule Knx.Knxnetip.CEMIFrame do
  defstruct src: nil,
            dest: nil,
            service: nil,
            apci: nil,
            asap: nil,
            tsap: nil,
            addr_t: nil,
            prio: 0,
            hops: nil,
            len: nil,
            seq: 0,
            eff: 0,
            data: <<>>,
            ok?: nil,
            message_code: nil,
            confirm: nil
end
