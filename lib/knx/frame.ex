defmodule Knx.Frame do
  @type t :: %__MODULE__{
          src: non_neg_integer() | nil,
          dest: non_neg_integer() | nil,
          service: Knx.Stack.Tl.service_t() | nil,
          apci: any(),
          seq: non_neg_integer(),
          asap: non_neg_integer(),
          tsap: non_neg_integer(),
          data: bitstring(),
          apdu: any(),
          addr_t: any(),
          prio: any(),
          hops: any(),
          eff: any(),
          len: any(),
          ok?: boolean()
        }

  @derive {Inspect, only: [:src, :service, :data, :seq]}
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
