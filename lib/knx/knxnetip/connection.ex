defmodule Knx.Knxnetip.Connection do
  defstruct id: nil,
            con_type: nil,
            client_seq_counter: 0,
            server_seq_counter: 0,
            dest_control_endpoint: nil,
            dest_data_endpoint: nil
end
