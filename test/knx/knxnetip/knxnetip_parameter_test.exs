defmodule Knx.KnxnetIp.KnxnetIpParameterTest do
  use ExUnit.Case

  alias Knx.KnxnetIp.KnxnetIpParameter, as: KnxnetIpParam

  @props Helper.get_knxnetip_parameter_props()

  test "get_current_ip_addr" do
    assert 0xC0A8B23E = KnxnetIpParam.get_current_ip_addr(@props)
  end

  test "get_knx_indv_addr" do
    assert 0x11FF = KnxnetIpParam.get_knx_indv_addr(@props)
  end

  test "get_routing_multicast_addr" do
    assert 0xE000170C = KnxnetIpParam.get_routing_multicast_addr(@props)
  end

  test "get_mac_addr" do
    assert 0x0 = KnxnetIpParam.get_mac_addr(@props)
  end

  test "get_friendly_name" do
    assert 0x4B4E_586E_6574_2F49_5020_4465_7669_6365_0000_0000_0000_0000_0000_0000_0000 =
             KnxnetIpParam.get_friendly_name(@props)
  end
end
