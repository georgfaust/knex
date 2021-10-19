defmodule Knx.KnxnetIp.Routing do
  alias Knx.KnxnetIp.Knip
  alias Knx.KnxnetIp.KnipFrame
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.Parameter, as: KnipParameter
  alias Knx.KnxnetIp.LeakyBucket
  alias Knx.DataCemiFrame
  alias Knx.State.KnxnetIp, as: KnipState

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  @moduledoc """
  The Routing module handles the body of KNXnet/IP-frames of the identically named
  service family.

  As a result, the updated knip_state and a list of impulses/effects are returned.
  Impulses include the respective response frames.
  """

  # ----------------------------------------------------------------------------
  # body handlers

  @doc """
  Handles body of KNXnet/IP frames.

  For every service type, there is one function clause.

  ## KNX specification

  For further information on the request services, refer to the
  following sections in document 03_08_05 (KNXnet/IP Routing):

    ROUTING_INDICATION: sections 2.3.2 (description) & 4.2.6 (structure)
    ROUTING_BUSY: sections 2.3.5 (description) & 5.4 (structure)
    ROUTING_LOST_MESSAGE: sections 2.3.4, 5.1 (description) & 5.3 (structure)

  """
  def handle_body(
        %KnipFrame{service_type_id: service_type_id(:routing_ind)},
        cemi_frame,
        %KnipState{} = knip_state
      ) do
    {knip_state, [{:dl, :up, cemi_frame}]}
  end

  def handle_body(
        %KnipFrame{service_type_id: service_type_id(:routing_busy)},
        <<
          structure_length(:busy_info)::8,
          _device_state::8,
          routing_busy_wait_time::16,
          routing_busy_control_field::16
        >>,
        %KnipState{} = knip_state
      ) do
    now = :os.system_time(:milli_seconds)
    routing_busy_count = recalculate_routing_busy_count(now, knip_state)

    delay_time =
      get_delay_time(routing_busy_control_field, routing_busy_wait_time, routing_busy_count)

    LeakyBucket.delay(delay_time)
    reset_time_routing_busy_count = now + delay_time + routing_busy_count * 100

    {%{
       knip_state
       | last_routing_busy: now,
         routing_busy_count: routing_busy_count,
         reset_time_routing_busy_count: reset_time_routing_busy_count
     }, []}
  end

  def handle_body(
        %KnipFrame{service_type_id: service_type_id(:routing_lost_message)},
        _body,
        %KnipState{} = knip_state
      ) do
    # no action required by regular KNX IP device
    {knip_state, []}
  end

  def handle_body(_ip_frame, _frame, %KnipState{} = knip_state) do
    warning(:no_matching_handler)
    {knip_state, []}
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  ### [private doc]
  # Produces impulse for ROUTING_INDICATION frame.
  #
  # KNX specification:
  #   Document 03_08_05, sections 5.1 (description) & 5.2 (structure)
  def routing_ind(cemi_frame) do
    total_len = structure_length(:header) + byte_size(cemi_frame)
    frame = Knip.header(service_type_id(:routing_ind), total_len) <> cemi_frame
    {:ip, :transmit, {get_multicast_endpoint(), frame}}
  end

  # ----------------------------------------------------------------------------
  # queue interface

  @doc """
  Enqueues cemi frame in leaky bucket queue.

  Allows sending of cemi frames to be deferred in order to avoid cache overload
  of KNXnet/IP routers.

  Called by driver.
  """
  def enqueue(cemi_frame) when is_binary(cemi_frame) do
    queue_size =
      cemi_frame
      |> DataCemiFrame.convert_message_code(:l_data_ind)
      |> routing_ind()
      |> LeakyBucket.enqueue()

    if queue_size == :queue_overflow do
      {props, _} =
        Cache.get_obj(:knxnet_ip_parameter) |> KnipParameter.increment_queue_overflow_to_ip()

      Cache.put_obj(:knxnet_ip_parameter, props)
    end

    queue_size
  end

  # ----------------------------------------------------------------------------
  # helper functions

  ### [private doc]
  # Returns endpoint containing standard multicast ip address and port.
  defp get_multicast_endpoint() do
    %Ep{
      protocol_code: protocol_code(:udp),
      ip_addr:
        Cache.get_obj(:knxnet_ip_parameter)
        |> KnipParameter.get_routing_multicast_addr()
        |> Knip.convert_number_to_ip(),
      port: 3671
    }
  end

  # [XXXIV]
  ### [private doc]
  # Determines routing busy count.
  #
  # Routing busy count is defined as the number of ROUTING_BUSY frames received in a moving period.
  #
  # See KNX Specification for more details: 03_08_05 2.3.5
  defp recalculate_routing_busy_count(
         now,
         %KnipState{
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

  ### [private doc]
  # Returns delay time for sending of ROUTING_INDICATION frames.
  #
  # See KNX Specification for more details: 03_08_05 2.3.5
  defp get_delay_time(control_field, wait_time, routing_busy_count) do
    if control_field == 0 do
      # get random number between 0 and 1
      random_number = :rand.uniform()
      wait_time + 50 * random_number * routing_busy_count
    else
      wait_time
    end
  end
end
