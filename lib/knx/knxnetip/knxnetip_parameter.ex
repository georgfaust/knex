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

  # ----------------------------------------------------------------------------

  def get_knxnetip_parameter_props() do
    current_ip_addr = 0xC0A802B5
    current_subnet_mask = 0xFFFFFF00
    current_default_gateway = 0xC0A80001
    mac_addr = 0x2CF05D52FCE8
    knx_addr = 0x11FF
    # friendly_name: "KNXnet/IP Device"
    friendly_name = 0x4B4E_586E_6574_2F49_5020_4465_7669_6365_0000_0000_0000_0000_0000_0000_0000

    [
      # TODO r_lvl
      P.new(:project_installation_id, [0x0000], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO has to be in sync with properties :subnet_addr and :device_addr of device object
      # TODO r_lvl, w_lvl
      P.new(:knx_individual_address, [knx_addr], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO first entry shall be length of list
      # TODO r_lvl, w_lvl, max
      P.new(:additional_individual_addresses, [0], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO current assignment method: DHCP; linked to ip_assignment_method?
      # TODO write, r_lvl, w_lvl
      P.new(:current_ip_assignment_method, [0x4], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO write, r_lvl, w_lvl
      P.new(:ip_assignment_method, [0x4], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO r_lvl
      P.new(:ip_capabilities, [0x1], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO shall be set according to Core, 8.5; linked to ip_address?
      # TODO r_lvl
      P.new(:current_ip_address, [current_ip_addr], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # linked to subnet_mask?
      # TODO write, r_lvl, w_lvl
      P.new(:current_subnet_mask, [current_subnet_mask], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # linked to default_gateway?
      # TODO write, r_lvl, w_lvl
      P.new(:current_default_gateway, [current_default_gateway],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      # TODO r_lvl
      P.new(:ip_address, [], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO r_lvl
      P.new(:subnet_mask, [], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO r_lvl
      P.new(:default_gateway, [], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO shall contain the IP address of the DHCP/BootP server
      # TODO r_lvl
      P.new(:dhcp_bootp_server, [], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO r_lvl
      P.new(:mac_address, [mac_addr], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO r_lvl
      P.new(:system_setup_multicast_address, [0xE000170C],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      # TODO change of value shall only become acitive after reset of device
      # TODO r_lvl, w_lvl
      P.new(:routing_multicast_address, [0xE000170C], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # TODO r_lvl, w_lvl
      P.new(:ttl, [0x10], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # TODO r_lvl
      P.new(:knxnetip_device_capabilities, [0x3], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO if the value of the Property changes the current value shall be sent using M_PropInfo.ind
      # TODO r_lvl
      P.new(:knxnetip_device_state, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # the following properties only have to be implemented by devices providing Routing
      # P.new(:knxnetip_routing_capabilities, [], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # P.new(:priority_fifo_enabled, [], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # TODO r_lvl
      P.new(:queue_overflow_to_ip, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO r_lvl
      P.new(:queue_overflow_to_knx, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # the following properties only have to be implemented by devices providing Routing
      # P.new(:msg_transmit_to_ip, [], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # P.new(:msg_transmit_to_knx, [], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO write, r_lvl, w_lvl
      P.new(:friendly_name, [friendly_name], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # valid value range: 20 - 100
      # TODO write, r_lvl, w_lvl
      P.new(:routing_busy_wait_time, [100], max: 1, write: true, r_lvl: 3, w_lvl: 2)
    ]
  end
end
