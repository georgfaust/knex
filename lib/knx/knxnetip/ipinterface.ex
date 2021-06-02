defmodule Knx.Knxnetip.IpInterface do
  alias Knx.Knxnetip.Core
  alias Knx.Knxnetip.DeviceManagement
  alias Knx.Knxnetip.IPFrame
  alias Knx.State, as: S

  import PureLogger

  @header_size 6
  @protocol_version 0x10

  # TODO
  ## - implement heartbeat monitoring
  ## - implement endpoint struct
  ## - defend additional individual addresses (tunneling, 2.2.2)
  ## - generate Layer-2 ack frames for additional individual addresses (tunneling, 2.2.2)

  # Open questions
  ## How does the server deal with ACKs?

  def handle({:ip, :from_ip, src, data}, %S{}) do
    # Core
    ## SEARCH_REQUEST -> SEARCH_RESPONSE
    ## DESCRIPTION_REQUEST -> DESCRIPTION_RESPONSE
    ## CONNECT_REQUEST -> CONNECT_RESPONSE
    ## CONNECTSTATE_REQUEST -> CONNECTSTATE_RESPONSE
    ## DISCONNECT_REQUEST -> DISCONNECT_RESPONSE
    ### [{:ethernet, :transmit, ip_frame}]

    # Device Management
    ## DEVICE_CONFIGURATION_REQUEST (.req) -> DEVICE_CONFIGURATION_ACK, DEVICE_CONFIGURATION_REQUEST (.con)
    ### [{:ethernet, :transmit, ip_frame1}, {:ethernet, :transmit, ip_frame2}]
    ## DEVICE_CONFIGURATION_ACK
    ### increment sequence counter

    # Tunneling
    ## TUNNELING_REQUEST -> TUNNELING_ACK, tp_frame
    ### [{:ethernet, :transmit, ip_frame}, {:dl, :req, %CEMIFrame{}}]
    ## TUNNELING_ACK
    ### increment sequence counter

    {ip_frame, body} = handle_header(data)

    module = cond do
      ip_frame.service_type_id < 0x300 -> Core
      ip_frame.service_type_id < 0x400 -> DeviceManagement
      ip_frame.service_type_id < 0x500 -> Tunneling
      true -> error(:unknown_service_familiy)
    end

    module.handle_body(src, ip_frame, body)

  end

  # ----------------------------------------------------------------------------

  defp handle_header(<<
         @header_size::8,
         @protocol_version::8,
         service_type_id::16,
         total_length::16,
         body::bits
       >>) do
    ip_frame = %IPFrame{
      service_type_id: service_type_id,
      total_length: total_length
    }

    {ip_frame, body}
  end

end
