defmodule Knx.KnxnetIp.IpFrame do
  alias Knx.Frame, as: F

  require Knx.Defs
  import Knx.Defs

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
            channel_id: nil,
            status_code: common_error_code(:no_error),
            client_seq_counter: nil,
            server_seq_counter: nil,
            knx_layer: nil,
            cemi: %F{}
end
