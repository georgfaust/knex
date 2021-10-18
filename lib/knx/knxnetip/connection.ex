defmodule Knx.KnxnetIp.Connection do
  @moduledoc """
  Struct for KNXnet/IP connections.

  id:                     connection id (must be unique)
  con_type:               either :device_mgmt_con or :tunnel_con
  client_seq_counter:     sequence counter of client
  server_seq_counter:     sequence counter of server
  dest_control_endpoint:  control endpoint of connected client
  dest_data_endpoint:     data endpoint of connected client
  con_knx_indv_addr:      knx individual address of connected client
  """
  defstruct id: nil,
            con_type: nil,
            client_seq_counter: 0,
            server_seq_counter: 0,
            dest_control_endpoint: nil,
            dest_data_endpoint: nil,
            con_knx_indv_addr: nil
end
