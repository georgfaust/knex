defmodule Knx.Knxnetip.Connection do
  defstruct id: nil,
            con_type: nil,
            ext_seq_counter: 0,
            own_seq_counter: 0,
            dest_endpoint: nil
end
