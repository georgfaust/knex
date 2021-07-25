defmodule Knx.KnxnetIp.Tunnelling do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.KnxnetIpParameter
  alias Knx.KnxnetIp.Queue
  alias Knx.State.KnxnetIp, as: IpState
  alias Knx.DataCemiFrame

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
        %IpFrame{service_type_id: service_type_id(:tunnelling_req), total_length: total_length} =
          ip_frame,
        <<
          structure_length(:connection_header_tunnelling)::8,
          channel_id::8,
          client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          data_cemi_frame::bits
        >> = body,
        %IpState{con_tab: con_tab, tunnelling_state: tunnelling_state} = ip_state
      ) do
    if ConTab.is_open?(con_tab, channel_id) do
      # TODO case
      if tunnelling_state == :idle do
        ip_frame = %{
          ip_frame
          | channel_id: channel_id,
            client_seq_counter: client_seq_counter,
            data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id)
        }

        case ConTab.compare_client_seq_counter(con_tab, channel_id, client_seq_counter) do
          :counter_equal ->
            con_tab = ConTab.increment_client_seq_counter(con_tab, channel_id)

            {%{ip_state | con_tab: con_tab, tunnelling_state: :waiting},
             [
               tunnelling_ack(ip_frame),
               {:driver, :transmit, data_cemi_frame},
               {:timer, :restart, {:ip_connection, channel_id}}
             ]}

          # [XXXII]
          :counter_off_by_minus_one ->
            ip_frame = %{ip_frame | client_seq_counter: client_seq_counter}

            {ip_state, [tunnelling_ack(ip_frame)]}

          # [XXXIII]
          :any_other_case ->
            {ip_state, []}
        end
      else
        frame = Ip.header(service_type_id(:tunnelling_req), total_length) <> body

        if Queue.enqueue(:tunnelling_queue, frame) == :queue_overflow do
          warning(:tunnelling_queue_overflow)
        end

        {ip_state, []}
      end
    else
      {ip_state, []}
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
        >>,
        %IpState{} = ip_state
      ) do
    # TODO trigger device restart
    {ip_state, []}
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
        >>,
        %IpState{con_tab: con_tab} = ip_state
      ) do
    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.server_seq_counter_equal?(con_tab, channel_id, server_seq_counter) do
      con_tab = ConTab.increment_server_seq_counter(con_tab, channel_id)

      {%{ip_state | con_tab: con_tab},
       [
         {:timer, :restart, {:ip_connection, channel_id}},
         {:timer, :stop, {:tunnelling_req, server_seq_counter}}
       ]}
    else
      {ip_state, []}
    end
  end

  def handle_body(_ip_frame, _frame, %IpState{} = ip_state) do
    warning(:no_matching_handler)
    {ip_state, []}
  end

  # ----------------------------------------------------------------------------
  # frame handler

  '''
  L_DATA.IND
  Description & Structure: 03_06_03:4.1.5.3.5
  L_DATA.CON
  Description & Structure: 03_06_03:4.1.5.3.4
  '''

  # handles both indications and confirmations received on knx
  # TODO cleaner solution: driver also returns knx indv src address
  def handle_up_frame(
        data_cemi_frame,
        %IpState{con_tab: con_tab, tunnelling_state: tunnelling_state} = ip_state
      ) do
    props = Cache.get_obj(:knxnet_ip_parameter)
    channel_id = con_tab[:tunnel_cons][KnxnetIpParameter.get_knx_indv_addr(props)]

    ip_frame = %IpFrame{
      # TODO if knx indv src address available via driver: look up channel id
      channel_id: channel_id,
      cemi: data_cemi_frame,
      data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id)
    }

    server_seq_counter = ConTab.get_server_seq_counter(con_tab, channel_id)

    ip_state =
      if tunnelling_state == :waiting && DataCemiFrame.is_con?(data_cemi_frame) &&
           Queue.pop(:tunnelling_queue) == :empty do
        %{ip_state | tunnelling_state: :idle}
      else
        ip_state
      end

    {ip_state,
     [
       tunnelling_req(ip_frame, con_tab),
       # TODO set tunneling_request_timeout = 1s
       {:timer, :start, {:tunnelling_req, server_seq_counter}}
     ]}
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  '''
  TUNNELLING REQUEST
  Description: 2.2, 2.6
  Structure: 4.4.6
  '''

  # Achtung! Leon, cemi_frame ist jetzt ein binary direkt vom driver!
  defp tunnelling_req(
         %IpFrame{
           channel_id: channel_id,
           cemi: data_cemi_frame,
           data_endpoint: data_endpoint
         },
         con_tab
       ) do
    frame =
      Ip.header(
        service_type_id(:tunnelling_req),
        Ip.get_structure_length([
          :header,
          :connection_header_tunnelling
        ]) + byte_size(data_cemi_frame)
      ) <>
        connection_header(
          channel_id,
          ConTab.get_server_seq_counter(con_tab, channel_id),
          knxnetip_constant(:reserved)
        ) <>
        data_cemi_frame

    {:ip, :transmit, {data_endpoint, frame}}
  end

  '''
  TUNNELLING ACK
  Description: 2.2, 2.6
  Structure: 4.4.7
  '''

  defp tunnelling_ack(%IpFrame{
         channel_id: channel_id,
         client_seq_counter: client_seq_counter,
         data_endpoint: data_endpoint
       }) do
    frame =
      Ip.header(
        service_type_id(:tunnelling_ack),
        Ip.get_structure_length([:header, :connection_header_tunnelling])
      ) <>
        connection_header(channel_id, client_seq_counter, common_error_code(:no_error))

    {:ip, :transmit, {data_endpoint, frame}}
  end

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
