defmodule Knx.KnxnetIp.Tunnelling do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.KnxnetIpParameter
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

  def handle_body(
        %IpFrame{
          service_type_id: service_type_id(:tunnelling_req),
          ip_src_endpoint: ip_src_endpoint,
          total_length: total_length
        } = ip_frame,
        <<
          structure_length(:connection_header_tunnelling)::8,
          channel_id::8,
          client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          data_cemi_frame::bits
        >> = body,
        %IpState{
          con_tab: con_tab,
          expd_tunnelling_con: expd_tunnelling_con,
          tunnelling_queue: tunnelling_queue,
          tunnelling_queue_size: tunnelling_queue_size
        } = ip_state
      ) do
    case expd_tunnelling_con do
      # don't wait for another frame to be confirmed: send data_cemi_frame to knx if seq counter correct
      :none ->
        ip_frame = %{
          ip_frame
          | channel_id: channel_id,
            client_seq_counter: client_seq_counter,
            data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id)
        }

        case ConTab.compare_client_seq_counter(con_tab, channel_id, client_seq_counter) do
          :counter_equal ->
            con_tab = ConTab.increment_client_seq_counter(con_tab, channel_id)

            {%{
               ip_state
               | con_tab: con_tab,
                 expd_tunnelling_con: DataCemiFrame.convert_to_cons(data_cemi_frame)
             },
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

      # wait for another frame to be confirmed: enqueue data_cemi_frame
      [pos_con: <<_::bits>>, neg_con: <<_::bits>>] ->
        frame = Ip.header(service_type_id(:tunnelling_req), total_length) <> body

        # TODO introduce max queue size? then: warn in case of overflow
        {%{
           ip_state
           | tunnelling_queue: :queue.in({ip_src_endpoint, frame}, tunnelling_queue),
             tunnelling_queue_size: tunnelling_queue_size + 1
         }, []}
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
    if ConTab.server_seq_counter_equal?(con_tab, channel_id, server_seq_counter) do
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

  # TODO server crasht, wenn er up_frame empfängt, ohne vorher connection aufgebaut zu haben
  #  -- function nil.server_seq_counter/0 is undefined
  # handle positive confirmations received on knx
  # tunnelling_queue_size = 0 : queue is empty, therefore only con must be sent
  # TODO cleaner solution: driver also returns knx indv src address
  def handle_up_frame(
        data_cemi_frame,
        %IpState{
          con_tab: con_tab,
          expd_tunnelling_con: [pos_con: data_cemi_frame, neg_con: _],
          tunnelling_queue_size: 0
        } = ip_state
      ) do
    server_seq_counter = ConTab.get_server_seq_counter(con_tab, get_channel_id(con_tab))

    {%{ip_state | expd_tunnelling_con: :none},
     [
       tunnelling_req(data_cemi_frame, con_tab),
       # TODO set tunneling_request_timeout = 1s
       {:timer, :start, {:tunnelling_req, server_seq_counter}}
     ]}
  end

  # handle positive confirmations received on knx
  # tunnelling_queue_size > 0 : queue is non-empty, therefore con must be sent
  #  and new impulse with popped frame must be generated
  def handle_up_frame(
        data_cemi_frame,
        %IpState{
          con_tab: con_tab,
          expd_tunnelling_con: [pos_con: data_cemi_frame, neg_con: _],
          tunnelling_queue: tunnelling_queue,
          tunnelling_queue_size: tunnelling_queue_size
        } = ip_state
      ) do
    server_seq_counter = ConTab.get_server_seq_counter(con_tab, get_channel_id(con_tab))
    {{:value, {ip_src_endpoint, frame}}, tunnelling_queue} = :queue.out(tunnelling_queue)

    {%{
       ip_state
       | tunnelling_queue: tunnelling_queue,
         tunnelling_queue_size: tunnelling_queue_size - 1,
         expd_tunnelling_con: DataCemiFrame.convert_to_cons(data_cemi_frame)
     },
     [
       tunnelling_req(data_cemi_frame, con_tab),
       {:timer, :start, {:tunnelling_req, server_seq_counter}},
       {:knip, :from_ip, {ip_src_endpoint, frame}}
     ]}
  end

  # handle negative confirmations received on knx
  def handle_up_frame(
        data_cemi_frame,
        %IpState{
          expd_tunnelling_con: [pos_con: _, neg_con: data_cemi_frame]
        } = ip_state
      ) do
    # TODO could this be problematic? could driver be repeatedly unable to send frame?
    {ip_state, [{:driver, :transmit, DataCemiFrame.convert_to_req(data_cemi_frame)}]}
  end

  # handle indications received on knx
  def handle_up_frame(
        <<cemi_message_code(:l_data_ind)::8, _rest::bits>> = data_cemi_frame,
        %IpState{
          con_tab: con_tab
        } = ip_state
      ) do
    server_seq_counter = ConTab.get_server_seq_counter(con_tab, get_channel_id(con_tab))

    {ip_state,
     [
       tunnelling_req(data_cemi_frame, con_tab),
       {:timer, :start, {:tunnelling_req, server_seq_counter}}
     ]}
  end

  # handle unexpected frames received on knx: ignore
  def handle_up_frame(
        _data_cemi_frame,
        %IpState{} = ip_state
      ) do
    {ip_state, []}
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  '''
  TUNNELLING REQUEST
  Description: 2.2, 2.6
  Structure: 4.4.6
  '''

  defp tunnelling_req(
         data_cemi_frame,
         con_tab
       ) do
    channel_id = get_channel_id(con_tab)
    data_endpoint = ConTab.get_data_endpoint(con_tab, channel_id)

    total_length =
      Ip.get_structure_length([:header, :connection_header_tunnelling]) +
        byte_size(data_cemi_frame)

    header = Ip.header(service_type_id(:tunnelling_req), total_length)

    connection_header =
      connection_header(
        channel_id,
        ConTab.get_server_seq_counter(con_tab, channel_id),
        knxnetip_constant(:reserved)
      )

    body = connection_header <> data_cemi_frame

    {:ip, :transmit, {data_endpoint, header <> body}}
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
    total_length = Ip.get_structure_length([:header, :connection_header_tunnelling])
    header = Ip.header(service_type_id(:tunnelling_ack), total_length)
    body = connection_header(channel_id, client_seq_counter, common_error_code(:no_error))

    {:ip, :transmit, {data_endpoint, header <> body}}
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

  # ----------------------------------------------------------------------------
  # helper function

  defp get_channel_id(con_tab) do
    # TODO if knx indv src address available via driver: look up channel id
    props = Cache.get_obj(:knxnet_ip_parameter)
    con_tab[:tunnel_cons][KnxnetIpParameter.get_knx_indv_addr(props)]
  end
end
