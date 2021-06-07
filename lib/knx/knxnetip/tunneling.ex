defmodule Knx.Knxnetip.Tunnelling do
  alias Knx.Knxnetip.IpInterface, as: Ip
  alias Knx.Knxnetip.IPFrame
  alias Knx.Knxnetip.TunnelCemiFrame
  alias Knx.Knxnetip.ConTab
  alias Knx.Frame, as: F
  alias Knx.Ail.Property, as: P

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  def handle_body(
        %IPFrame{service_type_id: service_type_id(:tunnelling_req)},
        <<
          structure_length(:connection_header)::8,
          _channel_id::8,
          _ext_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          cemi_message_code(:m_reset_req)::8
        >>
      ) do
    # TODO trigger device restart
  end

  def handle_body(
        %IPFrame{service_type_id: service_type_id(:tunnelling_req)} = ip_frame,
        <<
          structure_length(:connection_header)::8,
          channel_id::8,
          ext_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          cemi_message_code(:l_data_req)::8,
          0::8,
          frame_type::1,
          0::1,
          # TODO 1 means, DL repetitions may be sent. how do we handle this?
          repeat::1,
          _system_broadcast::1,
          prio::2,
          # TODO for TP1, L2-Acks are requested independent of value
          _ack::1,
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

    # TODO how does the server react if no connection is open? (not specified)
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
          ext_seq_counter: ext_seq_counter,
          data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id),
          cemi: cemi_frame
      }

      # TODO
      <<decremeted_ext_seq_counter>> = <<ext_seq_counter - 1>>

      cond do
        ConTab.ext_seq_counter_equal?(con_tab, channel_id, ext_seq_counter) ->
          con_tab = ConTab.increment_ext_seq_counter(con_tab, channel_id)
          Cache.put(:con_tab, con_tab)

          [
            tunnelling_ack(ip_frame),
            {:dl, :req, knx_frame(ip_frame.cemi)},
            tunnelling_req(ip_frame),
            {:timer, :restart, {:ip_connection, channel_id}}
          ]

        ConTab.ext_seq_counter_equal?(con_tab, channel_id, decremeted_ext_seq_counter) ->
          ip_frame = %{
            ip_frame
            | ext_seq_counter: ext_seq_counter - 1
          }

          [tunnelling_ack(ip_frame)]

        true ->
          []
      end
    else
      []
    end
  end

  def handle_body(
        %IPFrame{service_type_id: service_type_id(:tunnelling_ack)},
        <<
          structure_length(:connection_header)::8,
          channel_id::8,
          int_seq_counter::8,
          _status::8
        >>
      ) do
    con_tab = Cache.get(:con_tab)

    # TODO how should ACKs be handled by the server? (not specified)
    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.int_seq_counter_equal?(con_tab, channel_id, int_seq_counter) do
      con_tab = ConTab.increment_int_seq_counter(con_tab, channel_id)
      Cache.put(:con_tab, con_tab)
    end

    [{:timer, :restart, {:ip_connection, channel_id}}]
  end

  def handle_body(_ip_frame, _frame) do
    error(:unknown_service_type_id)
  end

  # ----------------------------------------------------------------------------

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
      # TODO 03_06_03 4.1.5.3.5
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
    channel_id = 0xFF

    con_tab = Cache.get(:con_tab)
    data_endpoint = ConTab.get_data_endpoint(con_tab, channel_id)

    ip_frame = %IPFrame{
      channel_id: channel_id,
      cemi: cemi_frame,
      data_endpoint: data_endpoint
    }

    [tunnelling_req(ip_frame)]
  end

  # ----------------------------------------------------------------------------

  defp tunnelling_req(%IPFrame{
         channel_id: channel_id,
         cemi: req_cemi,
         data_endpoint: data_endpoint
       }) do
    con_tab = Cache.get(:con_tab)
    int_seq_counter = ConTab.get_int_seq_counter(con_tab, channel_id)

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
        connection_header(channel_id, int_seq_counter, knxnetip_constant(:reserved)) <>
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

  defp tunnelling_ack(%IPFrame{
         channel_id: channel_id,
         ext_seq_counter: ext_seq_counter,
         data_endpoint: data_endpoint
       }) do
    frame =
      Ip.header(
        service_type_id(:tunnelling_ack),
        structure_length(:header) + connection_header_structure_length(:tunneling)
      ) <>
        connection_header(channel_id, ext_seq_counter, tunnelling_ack_status_code(:no_error))

    {:ethernet, :transmit, {data_endpoint, frame}}
  end

  # ----------------------------------------------------------------------------

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

  # [XXX]
  defp check_src_addr(src) do
    # TODO if multiple individual addresses will be supported, src might not be replaced
    if src == 0 do
      props = Cache.get_obj(:knxnet_ip_parameter)
      P.read_prop_value(props, :knx_individual_address)
    else
      src
    end
  end
end
