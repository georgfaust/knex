defmodule Knx.Knxnetip.IPFrame do
  alias Knx.Knxnetip.CEMIFrame

  defstruct header_size: 6,
            protocol_version: nil,
            service_type_id: nil,
            total_length: nil,
            channel_id: nil,
            sequence_counter: nil,
            cemi_message_code: nil,
            cemi: %CEMIFrame{}
end
