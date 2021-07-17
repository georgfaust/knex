defmodule Knx.Frame do
  @derive {Inspect, only: [:dest, :seq, :service, :apci, :data]}
  defstruct message_code: nil,
            frame_type: nil,
            # TODO
            repeat: nil,
            src: nil,
            dest: nil,
            service: nil,
            apci: nil,
            asap: nil,
            tsap: nil,
            addr_t: nil,
            prio: 0,
            hops: 6,
            len: nil,
            seq: 0,
            eff: 0,
            data: <<>>,
            confirm: 0
end
