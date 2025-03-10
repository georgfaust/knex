defmodule Knx.KnxnetIp.Parameter do
  alias Knx.Ail.Property, as: P
  alias Knx.KnxnetIp.Knip
  use Bitwise
  require Knx.Defs
  import Knx.Defs

  @doc """
  Returns value of property current_ip_address.
  """
  def get_current_ip_addr(props),
    do: P.read_prop_value(props, :current_ip_address)

  @doc """
  Returns value of property knx_individual_address.
  """
  def get_knx_indv_addr(props),
    do: P.read_prop_value(props, :knx_individual_address)

  @doc """
  Returns value of property knxnetip_device_state.
  """
  def get_device_state(props),
    do: P.read_prop_value(props, :knxnetip_device_state)

  @doc """
  Returns value of property mac_address.
  """
  def get_mac_addr(props),
    do: P.read_prop_value(props, :mac_address)

  @doc """
  Returns value of property friendly_name.
  """
  def get_friendly_name(props),
    do: P.read_prop_value(props, :friendly_name)

  @doc """
  Returns value of property friendly_name.
  """
  def get_routing_multicast_addr(props),
    do: P.read_prop_value(props, :routing_multicast_address)

  @doc """
  Returns value of property routing_busy_wait_time.
  """
  def get_busy_wait_time(props),
    do: P.read_prop_value(props, :routing_busy_wait_time)

  @doc """
  Returns value of property queue_overflow_to_knx.
  """
  def get_queue_overflow_to_knx(props),
    do: P.read_prop_value(props, :queue_overflow_to_knx)

  @doc """
  Increments value of property queue_overflow_to_ip by one.
  Max. value: 65535
  """
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

  @doc """
  Returns KNXnet/IP parameter object with sensible default values.

  Read from the environment: current_ip_address, current_subnet_mask, current_default_gateway,
    mac_addr, knx_indv_addr
  """
  def get_knxnetip_parameter_props() do
    current_ip_addr =
      Application.get_env(:knx, :ip_addr, {0, 0, 0, 0}) |> Knip.convert_ip_to_number()

    current_subnet_mask =
      Application.get_env(:knx, :subnet_mask, {255, 255, 255, 0}) |> Knip.convert_ip_to_number()

    current_default_gateway =
      Application.get_env(:knx, :default_gateway, {0, 0, 0, 0}) |> Knip.convert_ip_to_number()

    mac_addr = Application.get_env(:knx, :mac_addr, 0x000000000000)

    knx_addr = Application.get_env(:knx, :knx_indv_addr, 0x1101)

    friendly_name =
      Application.get_env(:knx, :friendly_name, "empty name (KNXnet/IP)")
      |> convert_friendly_name()

    [
      P.new(:object_type, [object_type(:knxnet_ip_parameter)],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      P.new(:project_installation_id, [0x0000], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:knx_individual_address, [knx_addr], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # first entry shall be length of list
      P.new(:additional_individual_addresses, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # current assignment method: DHCP;
      P.new(:current_ip_assignment_method, [0x4], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:ip_assignment_method, [0x4], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:ip_capabilities, [0x1], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:current_ip_address, [current_ip_addr], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:current_subnet_mask, [current_subnet_mask], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:current_default_gateway, [current_default_gateway],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      P.new(:ip_address, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:subnet_mask, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:default_gateway, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:dhcp_bootp_server, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:mac_address, [mac_addr], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:system_setup_multicast_address, [Knip.convert_ip_to_number({224, 0, 23, 12})],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      P.new(:routing_multicast_address, [Knip.convert_ip_to_number({224, 0, 23, 12})],
        max: 1,
        write: true,
        r_lvl: 3,
        w_lvl: 3
      ),
      P.new(:ttl, [0x10], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:knxnetip_device_capabilities, [0x3], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:knxnetip_device_state, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:queue_overflow_to_ip, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:queue_overflow_to_knx, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:friendly_name, [friendly_name], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # valid value range: 20 - 100
      P.new(:routing_busy_wait_time, [100], max: 1, write: true, r_lvl: 3, w_lvl: 1)
    ]
  end

  # ----------------------------------------------------------------------------

  @doc """
  Converts string from unicode to LATIN-1 and adds trailing zeros for friendly_name property.
  """
  def convert_friendly_name(string) do
    hex_string_list =
      :unicode.characters_to_binary(string, :utf8, :latin1)
      |> :binary.bin_to_list()
      |> Enum.map(fn x -> Integer.to_string(x, 16) end)

    trailing_zeros = max(30 - length(hex_string_list), 0)

    trailing_zeros_list =
      if trailing_zeros > 0 do
        for _i <- 1..trailing_zeros, do: "00"
      else
        []
      end

    {hex, _} = (hex_string_list ++ trailing_zeros_list) |> Enum.join("") |> Integer.parse(16)
    hex
  end
end
