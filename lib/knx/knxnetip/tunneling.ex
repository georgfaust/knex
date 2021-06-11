defmodule Knx.KnxnetIp.Tunnelling do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.TunnelCemiFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.KnxnetIpParameter, as: KnxnetIpProps
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

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:tunnelling_req)} = ip_frame,
        <<
          structure_length(:connection_header)::8,
          channel_id::8,
          client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          cemi_message_code(:l_data_req)::8,
          0::8,
          frame_type::1,
          0::1,
          # TODO 1 means, DL repetitions may be sent. how do we handle this? (03_06_03:4.1.5.3.3)
          repeat::1,
          # !info: don't care (03_06_03:4.1.5.3.3)
          _system_broadcast::1,
          prio::2,
          # TODO for TP1, L2-Acks are requested independent of value
          _ack::1,
          # !info: don't care (03_06_03:4.1.5.3.3)
          _confirm::1,
          addr_t::1,
          hops::3,
          0::4,
          src_addr::16,
          dest_addr::16,
          len::8,
          data::bits
        >>
      ) do
    con_tab = Cache.get(:con_tab)

    if ConTab.is_open?(con_tab, channel_id) do
      cemi_frame = %TunnelCemiFrame{
        message_code: cemi_message_code(:l_data_con),
        frame_type: frame_type,
        repeat: repeat,
        prio: prio,
        addr_t: addr_t,
        hops: hops,
        src: src_addr,
        dest: dest_addr,
        len: len,
        data: data
      }

      ip_frame = %{
        ip_frame
        | channel_id: channel_id,
          client_seq_counter: client_seq_counter,
          data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id),
          cemi: cemi_frame
      }

      cond do
        # condition 1: request carries expected seq counter
        ConTab.client_seq_counter_equal?(con_tab, channel_id, client_seq_counter) ->
          con_tab = ConTab.increment_client_seq_counter(con_tab, channel_id)
          Cache.put(:con_tab, con_tab)

          [
            tunnelling_ack(ip_frame),
            {:dl, :req, knx_frame(ip_frame.cemi)},
            tunnelling_req(ip_frame),
            {:timer, :restart, {:ip_connection, channel_id}}
          ]

        # condition 2: request carries expected seq counter - 1
        # [XXXII]
        ConTab.client_seq_counter_equal?(
          con_tab,
          channel_id,
          decrement_seq_counter(client_seq_counter)
        ) ->
          ip_frame = %{
            ip_frame
            | client_seq_counter: client_seq_counter - 1
          }

          [tunnelling_ack(ip_frame)]

        # condition 3: any other case
        # [XXXIII]
        true ->
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
          structure_length(:connection_header)::8,
          _channel_id::8,
          _client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          cemi_message_code(:m_reset_req)::8
        >>
      ) do
    # TODO trigger device restart
  end

  '''
  TUNNELLING ACK
  Description: 2.2, 2.6
  Structure: 4.4.7
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:tunnelling_ack)},
        <<
          structure_length(:connection_header)::8,
          channel_id::8,
          server_seq_counter::8,
          _status::8
        >>
      ) do
    con_tab = Cache.get(:con_tab)

    # TODO how should ACKs be handled by the server? (not specified)
    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.server_seq_counter_equal?(con_tab, channel_id, server_seq_counter) do
      Cache.put(:con_tab, ConTab.increment_server_seq_counter(con_tab, channel_id))
    end

    [{:timer, :restart, {:ip_connection, channel_id}}]
  end

  def handle_body(_ip_frame, _frame) do
    warning(:no_matching_handler)
  end

  # ----------------------------------------------------------------------------
  # knx frame handler

  '''
  L_DATA.IND
  Description & Structure: 03_06_03:4.1.5.3.5
  '''

  def handle_knx_frame(%F{
        prio: prio,
        addr_t: addr_t,
        hops: hops,
        src: src,
        dest: dest,
        len: len,
        data: data
      }) do
    cemi_frame = %TunnelCemiFrame{
      message_code: cemi_message_code(:l_data_ind),
      frame_type: if(len <= 15, do: 1, else: 0),
      # TODO repeat, see 03_06_03:4.1.5.3.5
      repeat: 1,
      prio: prio,
      addr_t: addr_t,
      hops: hops,
      src: src,
      dest: dest,
      len: len,
      data: data
    }

    # TODO if multiple indv knx addresses will be supported, correct channel must be identified
    ip_frame = %IpFrame{
      channel_id: 0xFF,
      cemi: cemi_frame,
      data_endpoint: ConTab.get_data_endpoint(Cache.get(:con_tab), 0xFF)
    }

    [tunnelling_req(ip_frame)]
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  '''
  TUNNELLING REQUEST
  Description: 2.2, 2.6
  Structure: 4.4.6

  L_DATA.X
  Description & Structure: 03_06_03:4.1.5.3.3 f.
  '''

  defp tunnelling_req(%IpFrame{
         channel_id: channel_id,
         cemi: req_cemi,
         data_endpoint: data_endpoint
       }) do
    # repeat, system_broadcast and ack bits are not interpreted by client and therefore set to 0
    repeat = system_broadcast = ack = 0

    # TODO: evaluate if error in l_data_req?
    confirm = 0

    # TODO: does every knx frame get the hop count value 7?
    hops = 7

    frame =
      Ip.header(
        service_type_id(:tunnelling_req),
        structure_length(:header) + structure_length(:connection_header) +
          structure_length(:cemi_l_data_without_data) + byte_size(req_cemi.data)
      ) <>
        connection_header(
          channel_id,
          ConTab.get_server_seq_counter(Cache.get(:con_tab), channel_id),
          knxnetip_constant(:reserved)
        ) <>
        <<
          req_cemi.message_code::8,
          0::8,
          req_cemi.frame_type::1,
          0::1,
          repeat::1,
          system_broadcast::1,
          req_cemi.prio::2,
          ack::1,
          confirm::1,
          req_cemi.addr_t::1,
          hops::3,
          0::4,
          check_src_addr(req_cemi.src)::16,
          req_cemi.dest::16,
          req_cemi.len::8,
          req_cemi.data::bits
        >>

    {:ethernet, :transmit, {data_endpoint, frame}}
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
        structure_length(:header) + connection_header_structure_length(:tunneling)
      ) <>
        connection_header(channel_id, client_seq_counter, common_error_code(:no_error))

    {:ethernet, :transmit, {data_endpoint, frame}}
  end

  # ----------------------------------------------------------------------------
  # knx frame & placeholder creators

  defp knx_frame(%TunnelCemiFrame{
         prio: prio,
         addr_t: addr_t,
         hops: hops,
         src: src,
         dest: dest,
         data: data
       }) do
    %F{data: data, prio: prio, src: check_src_addr(src), dest: dest, addr_t: addr_t, hops: hops}
  end

  defp connection_header(channel_id, seq_counter, last_octet) do
    <<
      connection_header_structure_length(:device_management),
      channel_id::8,
      seq_counter::8,
      last_octet::8
    >>
  end

  # ----------------------------------------------------------------------------
  # helper function

  # [XXX]
  defp check_src_addr(src) do
    # TODO if multiple individual addresses will be supported, src might not be replaced
    if src == 0 do
      KnxnetIpProps.get_knx_indv_addr(Cache.get_obj(:knxnet_ip_parameter))
    else
      src
    end
  end

  defp decrement_seq_counter(seq_counter) do
    # seq_counter is 8-bit unsigned value
    <<decremented_seq_counter>> = <<seq_counter - 1>>
    decremented_seq_counter
  end
end
