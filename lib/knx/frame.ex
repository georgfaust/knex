defmodule Knx.Frame do
  @derive {Inspect, only: [:service, :apci, :data]}
  defstruct src: nil,
            dest: nil,
            service: nil,
            apci: nil,
            asap: nil,
            tsap: nil,
            apdu: nil,
            addr_t: nil,
            prio: 0,
            hops: nil,
            len: nil,
            seq: 0,
            eff: 0,
            data: <<>>,
            ok?: nil
end
