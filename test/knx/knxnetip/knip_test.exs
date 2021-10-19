defmodule Knx.KnxnetIp.KnipTest do
  use ExUnit.Case

  alias Knx.KnxnetIp.Knip

  require Knx.Defs
  import Knx.Defs

  @header <<
    structure_length(:header)::8,
    protocol_version(:knxnetip)::8,
    service_family_id(:core)::8,
    service_type_id(:search_req)::8,
    6::16
  >>

  test "header" do
    assert @header = Knip.header(service_type_id(:search_req), 6)
  end

  test "get_structure_length" do
    assert 76 =
             Knip.get_structure_length([:header, :hpai, :dib_device_info, :dib_supp_svc_families])

    assert 31 =
             Knip.get_structure_length([
               :cri_device_mgmt_con,
               :cri_tunnel_con,
               :crd_device_mgmt_con,
               :crd_tunnel_con,
               :cemi_l_data_without_data,
               :busy_info,
               :lost_message_info
             ])
  end

  test "convert_ip_to_number" do
    assert 0xC0A80201 = Knip.convert_ip_to_number({192, 168, 2, 1})
    assert 0xE000170C = Knip.convert_ip_to_number({224, 0, 23, 12})
  end

  test "convert_number_to_ip" do
    assert {192, 168, 2, 1} = Knip.convert_number_to_ip(0xC0A80201)
    assert {224, 0, 23, 12} = Knip.convert_number_to_ip(0xE000170C)
  end
end
