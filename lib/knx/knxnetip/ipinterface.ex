defmodule Knx.Knxnetip.IpInterface do
  alias Knx.Knxnetip.IPFrame
  alias Knx.Knxnetip.CEMIFrame
  alias Knx.State, as: S

  require Knx.Defs
  import Knx.Defs

  @header_size 6

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
    ###[{:ethernet, :transmit, ip_frame}, {:dl, :req, %CEMIFrame{}}]

    handle_(src, data)

    ## TUNNELING_ACK
    ### increment sequence counter
  end

  # def handle({:ip, :from_bus, data}, %S{}) do
  #   # Tunneling
  #   ## tp_frame -> TUNNELING_REQUEST
  #   ### [{:ethernet, :transmit, ip_frame}]
  # end

  # ----------------------------------------

  defp handle_(src, data) do
    {ip_frame, body} = handle_header(data)
    handle_body(src, ip_frame, body)
  end

  # header always has same structure
  defp handle_header(<<
         @header_size::8,
         protocol_version::8,
         service_type_id::16,
         total_length::16,
         body::bits
       >>) do
    ip_frame = %IPFrame{
      protocol_version: protocol_version,
      service_type_id: service_type_id,
      total_length: total_length
    }

    {ip_frame, body}
  end

  # body varies depending on service_type_id
  defp handle_body(
         src,
         %IPFrame{service_type_id: service_type_id(:tunnelling_req)} = ip_frame,
         <<
           # structure length of connection header
           4::8,
           channel_id::8,
           sequence_counter::8,
           0::8,
           # begin of cemi frame
           cemi_message_code::8,
           0::8,
           cemi_service_info::bits
         >>
       ) do
    ip_frame = %{
      ip_frame
      | channel_id: channel_id,
        sequence_counter: sequence_counter,
        cemi_message_code: cemi_message_code,
        cemi: handle_cemi_service_info(cemi_message_code, cemi_service_info)
    }

    [tunneling_ack(src, ip_frame), {:dl, :req, ip_frame.cemi}]
  end

  # cemi_service_info always has same structure
  defp handle_cemi_service_info(
         cemi_message_code,
         <<
           # do we need to save the frame type?
           _frame_type::2,
           # TODO
           _repeat::1,
           # System Broadcast not applicable on TP1
           _system_broadcast::1,
           prio::2,
           # TP1: whether an ack is requested is determined by primitive
           _ack::1,
           # how do we handle this confirmation flag? is it identical with ok?
           confirm::1,
           addr_t::1,
           hops::3,
           eff::4,
           src::16,
           dest::16,
           len::8,
           data::bits
         >>
       ) do
    %CEMIFrame{
      message_code: cemi_message_code,
      src: src,
      dest: dest,
      addr_t: addr_t,
      prio: prio,
      hops: hops,
      len: len,
      data: data,
      eff: eff,
      confirm: confirm
    }
  end

  defp tunneling_ack(
         # {src_addr, src_port} = {dest_addr, dest_port}
         dest,
         %IPFrame{channel_id: channel_id, sequence_counter: sequence_counter}
       ) do
    frame = <<
      @header_size::8,
      # protocol version
      0x10::8,
      service_type_id(:tunnelling_ack)::16,
      # total length
      10::16,
      # structure length of connection header
      4::8,
      channel_id::8,
      sequence_counter::8,
      # TODO status
      0::8
    >>

    {:ethernet, :transmit, dest, frame}
  end
end
