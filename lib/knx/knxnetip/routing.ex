defmodule Knx.KnxnetIp.Routing do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.KnxnetIpParameter
  alias Knx.KnxnetIp.LeakyBucket
  alias Knx.DataCemiFrame
  alias Knx.State.KnxnetIp, as: IpState

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

  def handle_body(
        %IpFrame{
          service_type_id: service_type_id(:routing_ind),
          ip_src_endpoint: ip_src_endpoint
        },
        cemi_frame,
        %IpState{} = ip_state
      ) do
    current_ip_addr =
      Cache.get_obj(:knxnet_ip_parameter) |> KnxnetIpParameter.get_current_ip_addr()

    src_ip_addr = ip_src_endpoint.ip_addr |> Ip.convert_ip_to_number()

    # own ip signals echo from sending routing indication via multicast
    #  -> create local conf for go-server
    cemi_frame =
      if current_ip_addr == src_ip_addr do
        DataCemiFrame.convert_message_code(cemi_frame, :l_data_con)
      else
        cemi_frame
      end

    {ip_state, [{:dl, :up, cemi_frame}]}
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
        >>,
        %IpState{} = ip_state
      ) do
    # TODO a device state different from 0 indicates problems with access
    # to either KNX or IP network. Not explicitly stated, but use this info somehow?

    now = :os.system_time(:milli_seconds)
    routing_busy_count = recalculate_routing_busy_count(now, ip_state)

    delay_time =
      get_delay_time(routing_busy_control_field, routing_busy_wait_time, routing_busy_count)

    LeakyBucket.delay(delay_time)
    reset_time_routing_busy_count = now + delay_time + routing_busy_count * 100

    {%{
       ip_state
       | last_routing_busy: now,
         routing_busy_count: routing_busy_count,
         reset_time_routing_busy_count: reset_time_routing_busy_count
     }, []}
  end

  '''
  ROUTING LOST MESSAGE
  Description: 2.3.4, 5.1
  Structure: 5.3
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:routing_lost_message)},
        _body,
        %IpState{} = ip_state
      ) do
    # no action required by regular KNX IP device
    {ip_state, []}
  end

  def handle_body(_ip_frame, _frame, %IpState{} = ip_state) do
    warning(:no_matching_handler)
    {ip_state, []}
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  '''
  ROUTING INDICATION
  Description: 5.1, (2.3.5)
  Structure: 5.2
  '''

  def routing_ind(cemi_frame) do
    total_len = structure_length(:header) + byte_size(cemi_frame)
    frame = Ip.header(service_type_id(:routing_ind), total_len) <> cemi_frame
    {:ip, :transmit, {get_multicast_endpoint(), frame}}
  end

  # ----------------------------------------------------------------------------
  # queue interface

  def enqueue(cemi_frame) when is_binary(cemi_frame) do
    queue_size =
      cemi_frame
      |> DataCemiFrame.convert_message_code(:l_data_ind)
      |> routing_ind()
      |> LeakyBucket.enqueue()

    if queue_size == :queue_overflow do
      {props, _} =
        Cache.get_obj(:knxnet_ip_parameter) |> KnxnetIpParameter.increment_queue_overflow_to_ip()

      Cache.put_obj(:knxnet_ip_parameter, props)
    end

    queue_size
  end

  # ----------------------------------------------------------------------------
  # helper functions

  defp get_multicast_endpoint() do
    %Ep{
      protocol_code: protocol_code(:udp),
      ip_addr:
        Cache.get_obj(:knxnet_ip_parameter)
        |> KnxnetIpParameter.get_routing_multicast_addr()
        |> Ip.convert_number_to_ip(),
      port: 3671
    }
  end

  # [XXXIV]
  defp recalculate_routing_busy_count(
         now,
         %IpState{
           last_routing_busy: last_routing_busy,
           routing_busy_count: routing_busy_count,
           reset_time_routing_busy_count: reset_time_routing_busy_count
         }
       ) do
    routing_busy_count =
      if reset_time_routing_busy_count != nil && now > reset_time_routing_busy_count do
        decrements = floor((now - reset_time_routing_busy_count) / 5)
        max(routing_busy_count - decrements, 0)
      else
        routing_busy_count
      end

    if last_routing_busy != nil && now > last_routing_busy + 10 do
      routing_busy_count + 1
    else
      routing_busy_count
    end
  end

  defp get_delay_time(control_field, wait_time, routing_busy_count) do
    # TODO What is this supposed to mean?:
    # "If the ROUTING_BUSY Frame contains a routing busy control field value not equal to 0000h
    # then >>>any device that does not interpret this routing busy control field<<< SHALL stop sending
    # for the time tw."
    if control_field == 0 do
      # get random number between 0 and 1
      random_number = :rand.uniform()
      wait_time + 50 * random_number * routing_busy_count
    else
      wait_time
    end
  end
end
