defmodule Knx.Knxnetip.KnxnetipParameter do
  alias Knx.Ail.Property, as: P
  import Knx.Defs
  require Knx.Defs
  use Bitwise

  

  def get_current_ip_addr(props),
    do: P.read_prop_value(props, :current_ip_address)

  def get_knx_indv_addr(props),
    do: P.read_prop_value(props, :knx_individual_address)

  def get_routing_multicast_addr(props),
    do: P.read_prop_value(props, :routing_multicast_address)

  def get_mac_addr(props),
    do: P.read_prop_value(props, :mac_address)

  def get_friendly_name(props),
    do: P.read_prop_value(props, :friendly_name)

end
