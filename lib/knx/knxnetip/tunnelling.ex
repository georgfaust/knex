defmodule Knx.KnxnetIp.Tunnelling do
  alias Knx.KnxnetIp.Knip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.Parameter, as: KnipParameter
  alias Knx.State.KnxnetIp, as: IpState

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  @moduledoc """
  The Tunnelling module handles the body of KNXnet/IP-frames of the identically named
  service family.
  
  As a result, the updated ip_state and a list of impulses/effects are returned.
  Impulses include the respective response frames.
  """

  # ----------------------------------------------------------------------------
  # body handlers

  @doc """
  Handles body of KNXnet/IP frames.
  
  ## KNX specification
  
  For further information on the request services, refer to the
  following sections in document 03_08_04 (KNXnet/IP TUNNELLING):
  
    TUNNELLING_REQUEST: sections 2.2, 2.6 (description) & 4.4.6 (structure)
    TUNNELLING ACK: sections 2.2, 2.6 (description) & 4.4.7 (structure)
  
  """
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
    {ip_state, [{:restart, :ind, :knip}]}
  end

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
          last_data_cemi_frame: last_data_cemi_frame,
          tunnelling_queue: tunnelling_queue,
          tunnelling_queue_size: tunnelling_queue_size
        } = ip_state
      ) do
    case last_data_cemi_frame do
      # no frame to be confirmed: send data_cemi_frame to knx if seq counter correct
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

            :logger.debug(
              "[D: #{Process.get(:cache_id)}] tunnelling.req: received expected seq counter"
            )

            data_cemi_frame = replace_src_addr(data_cemi_frame)

            {%{
               ip_state
               | con_tab: con_tab,
                 last_data_cemi_frame: data_cemi_frame
             },
             [
               tunnelling_ack(ip_frame),
               {:driver, :transmit, data_cemi_frame},
               {:timer, :restart, {:ip_connection, channel_id}}
             ]}

          # [XXXII]
          :counter_off_by_minus_one ->
            ip_frame = %{ip_frame | client_seq_counter: client_seq_counter}

            :logger.debug(
              "[D: #{Process.get(:cache_id)}] tunnelling.req: seq counter is off by -1"
            )

            {ip_state, [tunnelling_ack(ip_frame)]}

          # [XXXIII]
          :any_other_case ->
            :logger.debug(
              "[D: #{Process.get(:cache_id)}] tunnelling.req: received unexpected seq counter"
            )

            {ip_state, []}
        end

      # wait for another frame to be confirmed: enqueue data_cemi_frame
      <<_::bits>> ->
        frame = Knip.header(service_type_id(:tunnelling_req), total_length) <> body

        :logger.debug("[D: #{Process.get(:cache_id)}] tunnelling.req: enqueue data cemi frame")

        {%{
           ip_state
           | tunnelling_queue: :queue.in({ip_src_endpoint, frame}, tunnelling_queue),
             tunnelling_queue_size: tunnelling_queue_size + 1
         }, []}
    end
  end

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

  @doc """
  Handles body of up frames (knx frames from bus).
  
  ## KNX specification
  
  For further information on the cemi frame definitions, refer to the
  following sections in document 03_06_03:
  
    L_DATA.IND: section 4.1.5.3.5 (description/structure)
    L_DATA.CON(F): section 4.1.5.3.4 (description/structure)
  
  """
  def handle_up_frame(
        <<cemi_message_code::8, _rest::bits>> = data_cemi_frame,
        %IpState{last_data_cemi_frame: last_data_cemi_frame} = ip_state
      ) do
    case cemi_message_code do
      cemi_message_code(:l_data_con) ->
        check_conf(data_cemi_frame, last_data_cemi_frame)
        |> handle_conf(data_cemi_frame, ip_state)

      cemi_message_code(:l_data_ind) ->
        handle_ind(data_cemi_frame, ip_state)

      _ ->
        {ip_state, []}
    end
  end

  def handle_conf(
        :pos_conf,
        data_cemi_frame,
        %IpState{con_tab: con_tab, tunnelling_queue_size: 0} = ip_state
      ) do
    :logger.debug(
      "[D: #{Process.get(:cache_id)}] received positive conf (tunnelling queue is empty)"
    )

    server_seq_counter = ConTab.get_server_seq_counter(con_tab, get_channel_id(con_tab))

    {%{ip_state | last_data_cemi_frame: :none},
     [
       tunnelling_req(data_cemi_frame, con_tab),
       {:timer, :start, {:tunnelling_req, server_seq_counter}}
     ]}
  end

  def handle_conf(
        :pos_conf,
        data_cemi_frame,
        %IpState{
          con_tab: con_tab,
          tunnelling_queue: tunnelling_queue,
          tunnelling_queue_size: tunnelling_queue_size
        } = ip_state
      ) do
    :logger.debug(
      "[D: #{Process.get(:cache_id)}] received positive conf (tunnelling queue is non-empty)"
    )

    server_seq_counter = ConTab.get_server_seq_counter(con_tab, get_channel_id(con_tab))
    {{:value, {ip_src_endpoint, frame}}, tunnelling_queue} = :queue.out(tunnelling_queue)

    {%{
       ip_state
       | tunnelling_queue: tunnelling_queue,
         tunnelling_queue_size: tunnelling_queue_size - 1,
         last_data_cemi_frame: :none
     },
     [
       tunnelling_req(data_cemi_frame, con_tab),
       {:timer, :start, {:tunnelling_req, server_seq_counter}},
       {:knip, :from_ip, {ip_src_endpoint, frame}}
     ]}
  end

  def handle_conf(
        :neg_conf,
        _data_cemi_frame,
        %IpState{
          # last_data_cemi_frame: last_data_cemi_frame
        } = ip_state
      ) do
    :logger.debug("[D: #{Process.get(:cache_id)}] received negative conf")

    # TODO could this be problematic? could driver be repeatedly unable to send frame?
    # {ip_state, [{:driver, :transmit, last_data_cemi_frame}]}
    {%{ip_state | last_data_cemi_frame: :none}, []}
  end

  def handle_conf(:unexpected_conf, _data_cemi_frame, %IpState{} = ip_state) do
    :logger.debug("[D: #{Process.get(:cache_id)}] received unexpected conf")

    {ip_state, []}
  end

  def handle_ind(
        data_cemi_frame,
        %IpState{con_tab: con_tab} = ip_state
      ) do
    :logger.debug("[D: #{Process.get(:cache_id)}] received ind")

    server_seq_counter = ConTab.get_server_seq_counter(con_tab, get_channel_id(con_tab))

    {ip_state,
     [
       tunnelling_req(data_cemi_frame, con_tab),
       {:timer, :start, {:tunnelling_req, server_seq_counter}}
     ]}
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  ### [private doc]
  # Produces impulse for TUNNELLING_REQUEST frame.
  #
  # KNX specification:
  #   Document 03_08_04, sections 2.2, 2.6 (description) & 4.4.6 (structure)
  defp tunnelling_req(
         data_cemi_frame,
         con_tab
       ) do
    channel_id = get_channel_id(con_tab)
    data_endpoint = ConTab.get_data_endpoint(con_tab, channel_id)

    total_length =
      Knip.get_structure_length([:header, :connection_header_tunnelling]) +
        byte_size(data_cemi_frame)

    header = Knip.header(service_type_id(:tunnelling_req), total_length)

    connection_header =
      connection_header(
        channel_id,
        ConTab.get_server_seq_counter(con_tab, channel_id),
        knxnetip_constant(:reserved)
      )

    body = connection_header <> data_cemi_frame

    {:ip, :transmit, {data_endpoint, header <> body}}
  end

  ### [private doc]
  # Produces impulse for TUNNELLING_ACK frame.
  #
  # KNX specification:
  #   Document 03_08_04, sections 2.2, 2.6 (description) & 4.4.7 (structure)
  defp tunnelling_ack(%IpFrame{
         channel_id: channel_id,
         client_seq_counter: client_seq_counter,
         data_endpoint: data_endpoint
       }) do
    total_length = Knip.get_structure_length([:header, :connection_header_tunnelling])
    header = Knip.header(service_type_id(:tunnelling_ack), total_length)
    body = connection_header(channel_id, client_seq_counter, common_error_code(:no_error))

    {:ip, :transmit, {data_endpoint, header <> body}}
  end

  # ----------------------------------------------------------------------------
  # placeholder creators

  ### [private doc]
  # Produces Connection Header.
  #
  # KNX specification:
  #   Document 03_08_02, section 5.3.1 (description/structure)
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

  ### [private doc]
  # Gets channel id from Cache.
  defp get_channel_id(con_tab) do
    props = Cache.get_obj(:knxnet_ip_parameter)
    con_tab[:tunnel_cons][KnipParameter.get_knx_indv_addr(props)]
  end

  ### [private doc]
  # Checks if L_Data confirmation matches request.
  defp check_conf(
         <<cemi_message_code(:l_data_con)::8, 0::8, r_control_1::8, tail::bits>>,
         <<cemi_message_code(:l_data_req)::8, 0::8, s_control_1::8, tail::bits>>
       ) do
    check_control_1_field(<<r_control_1>>, <<s_control_1>>)
  end

  defp check_conf(_received_frame, _sent_frame) do
    :unexpected_conf
  end

  ### [private doc]
  # Checks if control field of L_Data confirmation matches request.
  defp check_control_1_field(
         <<frame_type::1, 0::1, _r_dont_care::2, prio::2, ack::1, r_confirm::1>>,
         <<frame_type::1, 0::1, _s_dont_care::2, prio::2, ack::1, _s_confirm::1>>
       ) do
    if r_confirm == 0, do: :pos_conf, else: :neg_conf
  end

  defp check_control_1_field(_received_frame, _sent_frame) do
    :unexpected_conf
  end

  ### [private doc]
  # Replaces source address of data cemi frame with knx indv address of device.
  defp replace_src_addr(<<head::8*4, _src_addr::8*2, tail::bits>>) do
    device_src_addr = KnipParameter.get_knx_indv_addr(Cache.get_obj(:knxnet_ip_parameter))
    <<head::8*4, device_src_addr::8*2, tail::bits>>
  end
end
