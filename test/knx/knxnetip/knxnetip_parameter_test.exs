defmodule Knx.KnxnetIp.KnxnetIpParameterTest do
  use ExUnit.Case

  alias Knx.KnxnetIp.KnxnetIpParameter
  alias Knx.KnxnetIp.IpInterface, as: Ip

  @props KnxnetIpParameter.get_knxnetip_parameter_props()

  @friendly_name Application.get_env(:knx, :friendly_name, "empty name (KNXnet/IP)")
                 |> KnxnetIpParameter.convert_friendly_name()
  @knx_indv_addr Application.get_env(:knx, :knx_addr, 0x1101)
  @mac_addr Application.get_env(:knx, :mac_addr, 0x000000000000)
  @current_ip_addr Application.get_env(:knx, :ip_addr, {0, 0, 0, 0}) |> Ip.convert_ip_to_number()

  @ip_multicast_addr Ip.convert_ip_to_number({224, 0, 23, 12})

  setup do
    Cache.start_link(%{
      objects: [knxnet_ip_parameter: @props]
    })

    :timer.sleep(5)
    :ok
  end

  test "get_current_ip_addr" do
    assert @current_ip_addr = KnxnetIpParameter.get_current_ip_addr(@props)
  end

  test "get_knx_indv_addr" do
    assert @knx_indv_addr = KnxnetIpParameter.get_knx_indv_addr(@props)
  end

  test "get_device_state" do
    assert 0x0 = KnxnetIpParameter.get_device_state(@props)
  end

  test "get_mac_addr" do
    assert @mac_addr = KnxnetIpParameter.get_mac_addr(@props)
  end

  test "get_friendly_name" do
    assert @friendly_name = KnxnetIpParameter.get_friendly_name(@props)
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
