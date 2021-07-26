defmodule Knx.KnxnetIp.KnxnetIpParameterTest do
  use ExUnit.Case

  alias Knx.KnxnetIp.KnxnetIpParameter
  alias Knx.KnxnetIp.IpInterface, as: Ip

  @props KnxnetIpParameter.get_knxnetip_parameter_props()

  @device_ip_addr Ip.convert_ip_to_number({192, 168, 178, 62})
  @ip_multicast_addr Ip.convert_ip_to_number({224, 0, 23, 12})

  setup do
    Cache.start_link(%{
      objects: [knxnet_ip_parameter: @props]
    })

    :timer.sleep(5)
    :ok
  end

  test "get_current_ip_addr" do
    assert @device_ip_addr = KnxnetIpParameter.get_current_ip_addr(@props)
  end

  test "get_knx_indv_addr" do
    assert 0x11FF = KnxnetIpParameter.get_knx_indv_addr(@props)
  end

  test "get_device_state" do
    assert 0x0 = KnxnetIpParameter.get_device_state(@props)
  end

  test "get_mac_addr" do
    assert 0x2CF05D52FCE8 = KnxnetIpParameter.get_mac_addr(@props)
  end

  test "get_friendly_name" do
    assert 0x4B4E_586E_6574_2F49_5020_4465_7669_6365_0000_0000_0000_0000_0000_0000_0000 =
             KnxnetIpParameter.get_friendly_name(@props)
  end

  test "get_routing_multicast_addr" do
    assert @ip_multicast_addr = KnxnetIpParameter.get_routing_multicast_addr(@props)
  end

  test "get_busy_waiting_time" do
    assert 100 = KnxnetIpParameter.get_busy_wait_time(@props)
  end

  test "get_queue_overflow_to_knx" do
    assert 0 = KnxnetIpParameter.get_queue_overflow_to_knx(@props)
  end
end
