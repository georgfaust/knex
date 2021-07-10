defmodule Knx.KnxnetIp.KnxnetIpParameter do
  alias Knx.Ail.Property, as: P
  use Bitwise

  def get_current_ip_addr(props),
    do: P.read_prop_value(props, :current_ip_address)

  def get_knx_indv_addr(props),
    do: P.read_prop_value(props, :knx_individual_address)

  def get_device_state(props),
    do: P.read_prop_value(props, :knxnetip_device_state)

  def get_mac_addr(props),
    do: P.read_prop_value(props, :mac_address)

  def get_friendly_name(props),
    do: P.read_prop_value(props, :friendly_name)

  def get_routing_multicast_addr(props),
    do: P.read_prop_value(props, :routing_multicast_address)

  def get_busy_wait_time(props),
    do: P.read_prop_value(props, :routing_busy_wait_time)

  def get_queue_overflow_to_knx(props),
    do: P.read_prop_value(props, :queue_overflow_to_knx)

  def increment_queue_overflow_to_knx(props) do
    num = P.read_prop_value(props, :queue_overflow_to_knx)

    if num < 65535 do
      new_props = P.write_prop_value(props, :queue_overflow_to_knx, <<num + 1::16>>)

      {new_props, num + 1}
    else
      {props, num}
    end
  end

  def increment_queue_overflow_to_ip(props) do
    num = P.read_prop_value(props, :queue_overflow_to_ip)

    if num < 65535 do
      new_props = P.write_prop_value(props, :queue_overflow_to_ip, <<num + 1::16>>)

      {new_props, num + 1}
    else
      {props, num}
    end
  end
end
