defmodule Knx.KnxnetIp.KnipFrame do
  require Knx.Defs
  import Knx.Defs

  @moduledoc """
  Struct for information extracted from handled request frames.

  ip_src_endpoint:          endpoint of information from src ip package
  header_size:              header size of KNXnet/IP frame
  protocol_version:         protocol version of KNXnet/IP frame
  discovery_endpoint:       discovery endpoint of client
  control_endpoint:         control endpoint of client
  data_endpoint:            data endpoint of client
  service_family_id:        first byte of 'service_type_id' from knx specification
  service_type_id:          second byte of 'service_type_id' from knx specification
  total_length:             total length of KNXnet/IP frame
  con_type:                 either :device_mgmt_con or :tunnel_con
  channel_id:               channel id of coonection
  status_code:              error or status code (see defs.ex)
  client_seq_counter:       sequence counter of client
  server_seq_counter:       sequence counter of server
  knx_layer:                either :tunnel_linklayer or :tunnel_raw or :tunnel_busmonitor
  cemi:                     DataCemiFrame transported in KNX frame
  """
  defstruct ip_src_endpoint: nil,
            header_size: 6,
            protocol_version: 0x10,
            discovery_endpoint: nil,
            control_endpoint: nil,
            data_endpoint: nil,
            service_family_id: nil,
            service_type_id: nil,
            total_length: nil,
            con_type: nil,
            con_knx_indv_addr: nil,
            channel_id: nil,
            status_code: common_error_code(:no_error),
            client_seq_counter: nil,
            server_seq_counter: nil,
            knx_layer: nil,
            cemi: nil
end
