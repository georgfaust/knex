defmodule Knx.Knxnetip.IPTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Knxnetip.CEMIFrame
  alias Knx.Knxnetip.IpInterface, as: Ip
  alias Knx.Knxnetip.Connection, as: C

  require Knx.Defs
  import Knx.Defs

  @header_size 0x06
  @protocol_version 0x10

  @hpai_structure_length 8
  @dib_device_info_structure_length 0x36
  @dib_supp_svc_families_structure_length 8

  # 192.168.178.62
  @ip_interface_ip 0xC0A8_B23E
  # 3701 (14, 117)
  @ip_interface_port 0x0E75
  @ip_interface {@ip_interface_ip, @ip_interface_port}

  # 192.168.178.21
  @ets_ip 0xC0A8_B215
  # 60427
  @ets_port_discovery 0xEC0B
  # 52250
  @ets_port_control 0xCC1A
  @ets_discovery {@ets_ip, @ets_port_discovery}
  @ets_control {@ets_ip, @ets_port_control}

  @device_object Helper.get_device_props(1)
  @con %C{id: 0, con_type: :tunnel_con, dest_endpoint: {0xC0A8_B23E, 0x0E75}}

  setup do
    Cache.start_link(%{
      objects: [device: @device_object],
      con_tab: %{:free_ids => Enum.to_list(1..255), 0 => @con}
    })

    :timer.sleep(5)
    :ok
  end

  ## Search Req:
  @search_req <<0x0610_0201_000E_0801_C0A8_B215_EC0B::unit(8)-size(14)>>

  @total_length_search_resp @header_size + @hpai_structure_length +
                              @dib_device_info_structure_length +
                              @dib_supp_svc_families_structure_length

  test "search request" do
    assert [
             {:ethernet, :transmit,
              {:udp, @ets_discovery,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:search_resp)::16,
                 @total_length_search_resp::16,
                 # HPAI -------------------------------------
                 @hpai_structure_length::8,
                 host_protocol_code(:udp)::8,
                 @ip_interface_ip::32,
                 @ip_interface_port::16,
                 # DIB Device Info --------------------------
                 @dib_device_info_structure_length::8,
                 description_type_code(:device_info)::8,
                 # TODO
                 0x00::8,
                 1::8,
                 0x0000::16,
                 0x0000::16,
                 0x000000000000::48,
                 0x00000000::32,
                 0x000000000000::48,
                 0x000000000000000000000000000000::unit(8)-size(30),
                 # DIB Supported Service Families ------------
                 @dib_supp_svc_families_structure_length::8,
                 description_type_code(:supp_svc_families)::8,
                 0x02::8,
                 0x01::8,
                 0x03::8,
                 0x01::8,
                 0x04::8,
                 0x01::8
               >>}}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ets_discovery,
                 @search_req
               },
               %S{}
             )
  end

  ## Description Req:
  @description_req <<0x0610_0203_000E_0801_0000_0000_0000::unit(8)-size(14)>>

  @total_length_description_resp @header_size + @dib_device_info_structure_length +
                                   @dib_supp_svc_families_structure_length

  test "description request" do
    assert [
             {:ethernet, :transmit,
              {:udp, @ets_control,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:search_resp)::16,
                 @total_length_description_resp::16,
                 # DIB Device Info --------------------------
                 @dib_device_info_structure_length::8,
                 description_type_code(:device_info)::8,
                 # TODO
                 0x00::8,
                 1::8,
                 0x0000::16,
                 0x0000::16,
                 0x000000000000::48,
                 0x00000000::32,
                 0x000000000000::48,
                 0x000000000000000000000000000000::unit(8)-size(30),
                 # DIB Supported Service Families ------------
                 @dib_supp_svc_families_structure_length::8,
                 description_type_code(:supp_svc_families)::8,
                 0x02::8,
                 0x01::8,
                 0x03::8,
                 0x01::8,
                 0x04::8,
                 0x01::8
               >>}}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ets_control,
                 @description_req
               },
               %S{}
             )
  end

  ## Connect Req:
  @connect_req_tunneling <<0x0610_0205_001A_0801_C0A8_B215_CC1A_0801_C0A8_B215_CC1C_0404_0200::unit(
                             8
                           )-size(26)>>

  @connect_req_management <<0x0610_0205_0018_0801_C0A8_B215_CC1A_0801_C0A8_B215_CC1C_0203::unit(8)-size(
                              24
                            )>>

  @total_length_connect_resp_tunneling @header_size + 2 + @hpai_structure_length + 4
  @total_length_connect_resp_management @header_size + 2 + @hpai_structure_length + 2
  # TODO
  @knx_indv_addr 0x0000

  test("connect request") do
    assert [
             {:ethernet, :transmit,
              {:udp, @ets_control,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:connect_resp)::16,
                 @total_length_connect_resp_tunneling::16,
                 1::8,
                 connect_response_status_code(:no_error)::8,
                 @hpai_structure_length::8,
                 host_protocol_code(:udp)::8,
                 @ip_interface_ip::32,
                 @ip_interface_port::16,
                 4::8,
                 connection_type_code(:tunnel_con)::8,
                 @knx_indv_addr::16
               >>}}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ets_control,
                 @connect_req_tunneling
               },
               %S{}
             )

    assert [
             {:ethernet, :transmit,
              {:udp, @ets_control,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:connect_resp)::16,
                 @total_length_connect_resp_management::16,
                 2::8,
                 connect_response_status_code(:no_error)::8,
                 @hpai_structure_length::8,
                 host_protocol_code(:udp)::8,
                 @ip_interface_ip::32,
                 @ip_interface_port::16,
                 2::8,
                 connection_type_code(:device_mgmt_con)::8
               >>}}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ets_control,
                 @connect_req_management
               },
               %S{}
             )
  end

  ## Connectionstate Req:
  @connectionstate_req <<0x0610_0207_0010_0000_0801_C0A8_B215_CC1A::unit(8)-size(16)>>

  @total_length_connectionstate_resp @header_size + 2

  test("connectionstate request") do
    assert [
             {:ethernet, :transmit,
              {:udp, @ets_control,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:connectionstate_resp)::16,
                 @total_length_connectionstate_resp::16,
                 0::8,
                 connectionstate_response_status_code(:no_error)::8
               >>}}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ets_control,
                 @connectionstate_req
               },
               %S{}
             )
  end

  ## Disconnect Req:
  @disconnect_req <<0x0610_0209_0010_0000_0801_C0A8_B215_CC1A::unit(8)-size(16)>>

  @total_length_disconnect_resp @header_size + 2

  test("disconnect request") do
    assert [
             {:ethernet, :transmit,
              {:udp, @ets_control,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:disconnect_resp)::16,
                 @total_length_disconnect_resp::16,
                 0::8,
                 disconnect_response_status_code(:no_error)::8
               >>}}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ets_control,
                 @disconnect_req
               },
               %S{}
             )
  end

  ## Tunneling Req:
  @tunneling_req_group_value_write <<0x0610_0420_0015_049F_0000_2900_BCE0_2102_0001_0100_81::unit(
                                       8
                                     )-size(21)>>
  # cEMI Frame -----------------------------------------------------------------
  @cemi_message_code_l_data_ind 0x29
  # @additional_info 0x00
  # @frame_type 0x10
  @src 0x2102
  @dest 0x0001
  @prio 3
  @hops 6
  @len 1
  @data <<0x0081::unit(8)-size(2)>>
  @eff 0
  @confirm 0

  ## Tunneling Ack:
  # KNXnet/IP Header -----------------------------------------------------------
  @service_type_id_tunneling_ack 0x0421
  @total_length 0x000A
  # Connection Header ----------------------------------------------------------
  @structure_length_connection_header 0x04
  @channel_id 0x9F
  @ext_seq_counter 0x00
  @status 0x00

  test "tunneling request, group value write" do
    assert [
             {:ethernet, :transmit,
              {@ip_interface,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 @service_type_id_tunneling_ack::16,
                 @total_length::16,
                 @structure_length_connection_header::8,
                 @channel_id::8,
                 @ext_seq_counter::8,
                 @status::8
               >>}},
             {:dl, :req,
              %CEMIFrame{
                message_code: @cemi_message_code_l_data_ind,
                src: @src,
                dest: @dest,
                addr_t: addr_t(:grp),
                prio: @prio,
                hops: @hops,
                len: @len,
                data: @data,
                eff: @eff,
                confirm: @confirm
              }}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ip_interface,
                 @tunneling_req_group_value_write
               },
               %S{}
             )
  end
end
