defmodule Knx.KnxnetIp.ParameterTest do
  use ExUnit.Case

  alias Knx.Ail.Property, as: P
  alias Knx.KnxnetIp.Parameter, as: KnipParameter
  alias Knx.KnxnetIp.Knip

  @props KnipParameter.get_knxnetip_parameter_props()

  @friendly_name Application.compile_env(:knx, :friendly_name, "empty name (KNXnet/IP)")
                 |> KnipParameter.convert_friendly_name()
  @knx_indv_addr Application.compile_env(:knx, :knx_indv_addr, 0x1101)
  @mac_addr Application.compile_env(:knx, :mac_addr, 0x000000000000)
  @current_ip_addr Application.compile_env(:knx, :ip_addr, {0, 0, 0, 0})
                   |> Knip.convert_ip_to_number()

  @ip_multicast_addr Knip.convert_ip_to_number({224, 0, 23, 12})

  setup do
    Cache.start_link(%{
      objects: [knxnet_ip_parameter: @props]
    })

    :timer.sleep(5)
    :ok
  end

  test "get_current_ip_addr" do
    assert @current_ip_addr = KnipParameter.get_current_ip_addr(@props)
  end

  test "get_knx_indv_addr" do
    assert @knx_indv_addr = KnipParameter.get_knx_indv_addr(@props)
  end

  test "get_device_state" do
    assert 0x0 = KnipParameter.get_device_state(@props)
  end

  test "get_mac_addr" do
    assert @mac_addr = KnipParameter.get_mac_addr(@props)
  end

  test "get_friendly_name" do
    assert @friendly_name = KnipParameter.get_friendly_name(@props)
  end

  test "get_routing_multicast_addr" do
    assert @ip_multicast_addr = KnipParameter.get_routing_multicast_addr(@props)
  end

  test "get_busy_waiting_time" do
    assert 100 = KnipParameter.get_busy_wait_time(@props)
  end

  test "get_queue_overflow_to_knx" do
    assert 0 = KnipParameter.get_queue_overflow_to_knx(@props)
  end

  test "increment_queue_overflow_to_ip" do
    assert {_new_props, 1} = KnipParameter.increment_queue_overflow_to_ip(@props)
    props = P.write_prop_value(@props, :queue_overflow_to_ip, <<65535::16>>)
    assert {_new_props, 65535} = KnipParameter.increment_queue_overflow_to_ip(props)
  end
end
