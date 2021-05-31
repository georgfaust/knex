defmodule Knx.Knxnetip.Connection do
  defstruct id: nil,
            con_type: nil,
            ext_seq_counter: 0,
            int_seq_counter: 0,
            dest_data_endpoint: nil
end
