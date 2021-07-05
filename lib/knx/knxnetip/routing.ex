defmodule Knx.KnxnetIp.Routing do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.DataCemiFrame
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

  # TODO ? 4.3.1: test if number of characters received without error is consistent
  # with the content of the "Frame length" subfield
  def handle_body(%IpFrame{service_type_id: service_type_id(:routing_ind)}, body) do
    cemi_frame = DataCemiFrame.handle(body)

    # TODO move to right place
    {:ok, knx_queue_pid} = LeakyBucket.start_link(%{queue_type: :knx_queue, queue_poll_rate: 100})

    queue_size = LeakyBucket.enqueue(knx_queue_pid, DataCemiFrame.knx_frame_struct(cemi_frame))

    # TODO get latest indv src addr (this is only mock)
    src = %Ep{
      protocol_code: protocol_code(:udp),
      ip_addr: 0x12345678,
      port: 1000
    }

    case queue_size do
      5 -> [routing_busy(src)]
      10 -> [routing_busy(get_multicast_endpoint())]
      _ -> []
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
          _routing_busy_wait_time::16,
          routing_busy_control_field::16
        >>
      ) do
    # TODO a device state different from 0 indicates problems with access
    # to either KNX or IP network. Not explicitly stated, but use this info somehow?

    # TODO I don't understand the use of values different from 0
    if routing_busy_control_field == 0 do
      # TODO calculate delay; depends on routing_busy_wait_time, see 2.3.5
      delay_time = 100

      # TODO move to right place
      {:ok, ip_queue_pid} = LeakyBucket.start_link(%{queue_type: :ip_queue, queue_poll_rate: 20})

      LeakyBucket.delay(ip_queue_pid, delay_time)
      []
    else
      []
    end
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
  def routing_ind(%F{} = knx_frame, dest_endpoint) do
    cemi_struct = DataCemiFrame.handle_knx_frame_struct(knx_frame)

    frame =
      Ip.header(
        service_type_id(:routing_ind),
        Ip.get_structure_length([
          :header,
          :cemi_l_data_without_data
        ]) + byte_size(cemi_struct.data)
      ) <>
        DataCemiFrame.create(cemi_struct)

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
          # TODO this is the routing busy control_field. I don't understand values different from 0
          0x0000::16
        >>

    {:ethernet, :transmit, {dest_endpoint, frame}}
  end

  '''
  ROUTING LOST MESSAGE
  Description: 2.3.4, 5.1
  Structure: 5.3
  '''

  # TODO in event of overflow of LAN-to-KNX queue, increment PID_QUEUE_OVERFLOW_TO_KNX
  # and send routing_lost_message
  defp routing_lost_message() do
    props = Cache.get_obj(:knxnet_ip_parameter)

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
          KnxnetIpParam.get_device_state(props)::8,
          KnxnetIpParam.get_queue_overflow_to_knx(props)::16
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
end
