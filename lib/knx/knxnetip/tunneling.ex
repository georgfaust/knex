defmodule Knx.KnxnetIp.Tunnelling do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.Frame, as: F

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  # ----------------------------------------------------------------------------
  # body handlers

  '''
  TUNNELLING REQUEST
  Description: 2.2, 2.6
  Structure: 4.4.6
  '''

  # ref-frm: binary -> data-cemi-frame -> frame / .message_code = con (falsch!?)
  def handle_body(
        %IpFrame{service_type_id: service_type_id(:tunnelling_req)} = _ip_frame,
        <<
          structure_length(:connection_header_tunnelling)::8,
          channel_id::8,
          client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          data_cemi_frame::bits
        >>
      ) do
    con_tab = Cache.get(:con_tab)

    if ConTab.is_open?(con_tab, channel_id) do
      # TODO Leon conf/ack bei TP-conf ..!?
      # Achtung --- DataCemiFrame.handle heisst jetzt:
      #   {_primitve, frame} = DataCemiFrame.decode(data_cemi_frame)
      # sollte dann hier aber nicht gebraucht werden da du direkt ein conf-cemi bekommst bei TP-conf
      # cemi_frame = DataCemiFrame.handle(data_cemi_frame)
      # ip_frame = %{
      #   ip_frame
      #   | channel_id: channel_id,
      #     client_seq_counter: client_seq_counter,
      #     data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id),
      #     cemi: %DataCemiFrame{cemi_frame | message_code: cemi_message_code(:l_data_con)}
      # }

      case ConTab.compare_client_seq_counter(con_tab, channel_id, client_seq_counter) do
        :counter_equal ->
          con_tab = ConTab.increment_client_seq_counter(con_tab, channel_id)
          Cache.put(:con_tab, con_tab)

          [
            # TODO Leon ACK bei TP-conf ...!?
            # tunnelling_ack(ip_frame),
            {:driver, :transmit, data_cemi_frame},
            # TODO Leon conf bei TP-conf
            # tunnelling_req(ip_frame),
            {:timer, :restart, {:ip_connection, channel_id}}
          ]

        # TODO Leon
        # # [XXXII]
        # :counter_off_by_minus_one ->
        #   ip_frame = %{ip_frame | client_seq_counter: client_seq_counter}

        #   [tunnelling_ack(ip_frame)]

        # [XXXIII]
        :any_other_case ->
          []
      end
    else
      []
    end
  end

  '''
  M_RESET_REQ
  Description & Structure: 03_06_03:4.1.7.5.1
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:tunnelling_req)},
        <<
          structure_length(:connection_header_tunnelling)::8,
          _channel_id::8,
          _client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          cemi_message_code(:m_reset_req)::8
        >>
      ) do
    # TODO trigger device restart
    []
  end

  '''
  TUNNELLING ACK
  Description: 2.2, 2.6
  Structure: 4.4.7
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:tunnelling_ack)},
        <<
          structure_length(:connection_header_tunnelling)::8,
          channel_id::8,
          server_seq_counter::8,
          _status_code::8
        >>
      ) do
    con_tab = Cache.get(:con_tab)

    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.server_seq_counter_equal?(con_tab, channel_id, server_seq_counter) do
      Cache.put(:con_tab, ConTab.increment_server_seq_counter(con_tab, channel_id))

      [
        {:timer, :restart, {:ip_connection, channel_id}},
        {:timer, :stop, {:device_management_req, server_seq_counter}}
      ]
    else
      []
    end
  end

  def handle_body(_ip_frame, _frame) do
    warning(:no_matching_handler)
    []
  end

  # ----------------------------------------------------------------------------
  # frame handler

  '''
  L_DATA.IND
  Description & Structure: 03_06_03:4.1.5.3.5
  '''

  def handle_up_frame(%F{} = cemi_frame) do
    # TODO if multiple indv knx addresses will be supported, correct channel must be identified
    ip_frame = %IpFrame{
      channel_id: 0xFF,
      cemi: cemi_frame,
      data_endpoint: ConTab.get_data_endpoint(Cache.get(:con_tab), 0xFF)
    }

    [
      tunnelling_req(ip_frame),
      # TODO set tunneling_request_timeout = 1s
      {:timer, :start, {:tunneling_req, ConTab.get_server_seq_counter(Cache.get(:con_tab), 0xFF)}}
    ]
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  '''
  TUNNELLING REQUEST
  Description: 2.2, 2.6
  Structure: 4.4.6
  '''

  # Achtung! Leon, cemi_frame ist jetzt ein binary direkt vom driver!
  defp tunnelling_req(%IpFrame{
         channel_id: channel_id,
         cemi: cemi_frame,
         data_endpoint: data_endpoint
       }) do
    frame =
      Ip.header(
        service_type_id(:tunnelling_req),
        Ip.get_structure_length([
          :header,
          :connection_header_tunnelling
        ]) + byte_size(cemi_frame)
      ) <>
        connection_header(
          channel_id,
          ConTab.get_server_seq_counter(Cache.get(:con_tab), channel_id),
          knxnetip_constant(:reserved)
        ) <>
        cemi_frame

    {:ethernet, :transmit, {data_endpoint, frame}}
  end

  '''
  TUNNELLING ACK
  Description: 2.2, 2.6
  Structure: 4.4.7
  '''

  # defp tunnelling_ack(%IpFrame{
  #        channel_id: channel_id,
  #        client_seq_counter: client_seq_counter,
  #        data_endpoint: data_endpoint
  #      }) do
  #   frame =
  #     Ip.header(
  #       service_type_id(:tunnelling_ack),
  #       Ip.get_structure_length([:header, :connection_header_tunnelling])
  #     ) <>
  #       connection_header(channel_id, client_seq_counter, common_error_code(:no_error))

  #   {:ethernet, :transmit, {data_endpoint, frame}}
  # end

  # ----------------------------------------------------------------------------
  # placeholder creators

  defp connection_header(channel_id, seq_counter, last_octet) do
    <<
      structure_length(:connection_header_tunnelling),
      channel_id::8,
      seq_counter::8,
      last_octet::8
    >>
  end
end
