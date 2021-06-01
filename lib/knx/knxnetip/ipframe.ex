defmodule Knx.Knxnetip.IPFrame do
  alias Knx.Knxnetip.CEMIFrame

  defstruct header_size: 6,
            protocol_version: 0x10,
            control_host_protocol_code: nil,
            control_endpoint: nil,
            data_host_protocol_code: nil,
            data_endpoint: nil,
            service_type_id: nil,
            total_length: nil,
            con_type: nil,
            channel_id: nil,
            status: :no_error,
            ext_seq_counter: nil,
            int_seq_counter: nil,
            knx_layer: nil,
            cemi: %CEMIFrame{}
end
