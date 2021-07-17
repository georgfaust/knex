defmodule Knx.KnxnetIp.Routing do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.DataCemiFrame
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.KnxnetIpParameter, as: KnxnetIpParam
  alias Knx.Frame, as: F
  alias Knx.KnxnetIp.LeakyBucket

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  # ----------------------------------------------------------------------------
  # body handlers

  '''
  ROUTING INDICATION
  Description: 5.1, (2.3.5)
  Structure: 5.2
  '''

  # ref-frm: binary -> data-cemi-frame -> frame / kein field access
  def handle_body(
        %IpFrame{
          service_type_id: service_type_id(:routing_ind),
          ip_src_endpoint: ip_src_endpoint
        },
        body
      ) do
    {_, cemi_frame} = DataCemiFrame.decode(body)

    case LeakyBucket.enqueue(
           :knx_queue,
           {ip_src_endpoint, cemi_frame}
         ) do
      :queue_overflow ->
        {new_props, number_of_lost_messages} =
          KnxnetIpParam.increment_queue_overflow_to_knx(Cache.get_obj(:knxnet_ip_parameter))

        Cache.put_obj(:knxnet_ip_parameter, new_props)
        [routing_lost_message(number_of_lost_messages)]

      5 ->
        [routing_busy(ip_src_endpoint)]

      10 ->
        [routing_busy(get_multicast_endpoint())]

      _ ->
        []
    end
  end

  '''
  ROUTING BUSY
  Description: 2.3.5
  Structure: 5.4
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:routing_busy)},
        <<
          structure_length(:busy_info)::8,
          _device_state::8,
          routing_busy_wait_time::16,
          routing_busy_control_field::16
        >>
      ) do
    # TODO a device state different from 0 indicates problems with access
    # to either KNX or IP network. Not explicitly stated, but use this info somehow?

    LeakyBucket.delay(
      :ip_queue,
      get_delay_time(routing_busy_control_field, routing_busy_wait_time)
    )

    []
  end

  '''
  ROUTING LOST MESSAGE
  Description: 2.3.4, 5.1
  Structure: 5.3
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:routing_lost_message)},
        _body
      ) do
    # no action required by regular KNX IP device
    []
  end

  def handle_body(_ip_frame, _frame) do
    warning(:no_matching_handler)
    []
  end

  # ----------------------------------------------------------------------------
  # queue handler

  def handle_queue(:ip_queue, %F{} = knx_frame) do
    [routing_ind(knx_frame, get_multicast_endpoint())]
  end

  def handle_queue(:knx_queue, %F{} = knx_frame) do
    [{:dl, :req, knx_frame}]
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  '''
  ROUTING INDICATION
  Description: 5.1, (2.3.5)
  Structure: 5.2
  '''

  # TODO what are the use cases of KNX IP devices sending routing indications?
  # when do we send routing indications?
  # TODO in case of overflow of ip_queue, increment PID queue_overflow_to_ip
  # ref-frm: frame -> data-cemi-frame -> binary  / byte_size(cemi_struct.data) (sieht falsch aus)
  def routing_ind(%F{} = cemi_frame, dest_endpoint) do
    cemi_frame = DataCemiFrame.encode(:req, cemi_frame)
    header_len = Ip.get_structure_length([:header]) + byte_size(cemi_frame)
    frame = Ip.header(service_type_id(:routing_ind), header_len) <> cemi_frame
    {:ethernet, :transmit, {dest_endpoint, frame}}
  end

  '''
  ROUTING BUSY
  Description: 2.3.5
  Structure: 5.4
  '''

  defp routing_busy(dest_endpoint) do
    props = Cache.get_obj(:knxnet_ip_parameter)

    frame =
      Ip.header(
        service_type_id(:routing_busy),
        Ip.get_structure_length([
          :header,
          :busy_info
        ])
      ) <>
        <<
          structure_length(:busy_info)::8,
          KnxnetIpParam.get_device_state(props)::8,
          KnxnetIpParam.get_busy_wait_time(props)::16,
          0x0000::16
        >>

    {:ethernet, :transmit, {dest_endpoint, frame}}
  end

  '''
  ROUTING LOST MESSAGE
  Description: 2.3.4, 5.1
  Structure: 5.3
  '''

  defp routing_lost_message(number_of_lost_messages) do
    frame =
      Ip.header(
        service_type_id(:routing_lost_message),
        Ip.get_structure_length([
          :header,
          :lost_message_info
        ])
      ) <>
        <<
          structure_length(:lost_message_info)::8,
          KnxnetIpParam.get_device_state(Cache.get_obj(:knxnet_ip_parameter))::8,
          number_of_lost_messages::16
        >>

    {:ethernet, :transmit, {get_multicast_endpoint(), frame}}
  end

  # ----------------------------------------------------------------------------
  # helper function

  defp get_multicast_endpoint() do
    %Ep{
      protocol_code: protocol_code(:udp),
      ip_addr: KnxnetIpParam.get_routing_multicast_addr(Cache.get_obj(:knxnet_ip_parameter)),
      port: 3671
    }
  end

  defp get_delay_time(control_field, wait_time) do
    # TODO What is this supposed to mean?:
    # "If the ROUTING_BUSY Frame contains a routing busy control field value not equal to 0000h
    # then any device that does not interpret this routing busy control field SHALL stop sending
    # for the time tw."
    if control_field == 0 do
      # get random number between 0 and 1
      :random.seed(:erlang.now())
      random_number = :random.uniform()

      # TODO calc routing busy count: need state for that
      routing_busy_count = 1
      wait_time + 50 * random_number * routing_busy_count
    else
      wait_time
    end
  end
end
