defmodule Knx.KnxnetIp.KnxnetIpParameter do
  alias Knx.Ail.Property, as: P
  alias Knx.KnxnetIp.IpInterface, as: Ip
  use Bitwise
  require Knx.Defs
  import Knx.Defs

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

  def get_knxnetip_parameter_props(ia) do
    # TODO ip_addr shall be 0.0.0.0 if no addr was assigned according to Core 8.5.1.4
    # TODO if DHCP: get address assigned from DHCP - if static: get static address
    # TODO: wenn static IP per prop write oder parameter geaendert wird -> IP aendert
    current_ip_addr =
      Application.get_env(:knx, :ip_addr, {0, 0, 0, 0}) |> Ip.convert_ip_to_number()

    current_subnet_mask =
      Application.get_env(:knx, :subnet_mask, {255, 255, 255, 0}) |> Ip.convert_ip_to_number()

    current_default_gateway =
      Application.get_env(:knx, :default_gateway, {0, 0, 0, 0}) |> Ip.convert_ip_to_number()

    mac_addr = Application.get_env(:knx, :mac_addr, 0x000000000000)

    # friendly_name: "KNXnet/IP Device"
    friendly_name = 0x4B4E_586E_6574_2F49_5020_4465_7669_6365_0000_0000_0000_0000_0000_0000_0000

    [
      P.new(:object_type, [object_type(:knxnet_ip_parameter)],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      P.new(:project_installation_id, [0x0000], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # TODO has to be in sync with properties :subnet_addr and :device_addr of device object
      P.new(:knx_individual_address, [ia], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # first entry shall be length of list
      P.new(:additional_individual_addresses, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # current assignment method: DHCP;
      P.new(:current_ip_assignment_method, [0x4], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:ip_assignment_method, [0x4], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:ip_capabilities, [0x1], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO shall be set according to Core, 8.5; linked to ip_address?
      P.new(:current_ip_address, [current_ip_addr], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # linked to subnet_mask?
      P.new(:current_subnet_mask, [current_subnet_mask], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # linked to default_gateway?
      P.new(:current_default_gateway, [current_default_gateway],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      P.new(:ip_address, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:subnet_mask, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:default_gateway, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # TODO shall contain the IP address of the DHCP/BootP server
      P.new(:dhcp_bootp_server, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:mac_address, [mac_addr], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:system_setup_multicast_address, [Ip.convert_ip_to_number({224, 0, 23, 12})],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      # TODO change of value shall only become acitive after reset of device
      P.new(:routing_multicast_address, [Ip.convert_ip_to_number({224, 0, 23, 12})],
        max: 1,
        write: true,
        r_lvl: 3,
        w_lvl: 3
      ),
      P.new(:ttl, [0x10], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:knxnetip_device_capabilities, [0x3], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO if the value of the Property changes the current value shall be sent using M_PropInfo.ind
      P.new(:knxnetip_device_state, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:queue_overflow_to_ip, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:queue_overflow_to_knx, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:friendly_name, [friendly_name], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # valid value range: 20 - 100
      P.new(:routing_busy_wait_time, [100], max: 1, write: true, r_lvl: 3, w_lvl: 1)
    ]
  end
end
