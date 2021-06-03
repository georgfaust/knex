defmodule Knx.Knxnetip.IPFrame do
  alias Knx.Knxnetip.TunnelCemiFrame

  defstruct ip_src: nil,
            header_size: 6,
            protocol_version: 0x10,
            control_endpoint: nil,
            data_endpoint: nil,
            service_type_id: nil,
            total_length: nil,
            con_type: nil,
            channel_id: nil,
            status: :no_error,
            ext_seq_counter: nil,
            int_seq_counter: nil,
            knx_layer: nil,
            cemi: %TunnelCemiFrame{}
end
