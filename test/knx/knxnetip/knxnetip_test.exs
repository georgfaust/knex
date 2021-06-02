defmodule Knx.Knxnetip.IPTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Knxnetip.CEMIFrame
  alias Knx.Knxnetip.IpInterface, as: Ip
  alias Knx.Knxnetip.Connection, as: C
  alias Knx.Knxnetip.Endpoint, as: Ep

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
  # @ip_interface {@ip_interface_ip, @ip_interface_port}

  # 192.168.178.21
  @ets_ip 0xC0A8_B215

  # 60427
  @ets_port_discovery 0xEC0B
  # 52250
  @ets_port_control 0xCC1A
  # 52252
  @ets_port_config_data 0xCC1C
  # 52252
  @ets_port_tunneling_data 0xCC1C

  @ets_discovery_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_discovery
  }

  @ets_control_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_control
  }

  @ets_config_data_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_config_data
  }

  @ets_tunneling_data_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_tunneling_data
  }

  @device_object Helper.get_device_props(1)
  @knxnet_ip_parameter_object Helper.get_knxnetip_parameter_props()

  @con_0 %C{id: 0, con_type: :device_mgmt_con, dest_data_endpoint: {0xC0A8_B23E, 0x0E75}}
  @con_254 %C{id: 254, con_type: :device_mgmt_con, dest_data_endpoint: @ets_config_data_endpoint}

  setup do
    Cache.start_link(%{
      objects: [device: @device_object, knxnet_ip_parameter: @knxnet_ip_parameter_object],
      con_tab: %{:free_mgmt_ids => Enum.to_list(1..253), 0 => @con_0, 254 => @con_254}
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
              {@ets_discovery_endpoint,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:search_resp)::16,
                 @total_length_search_resp::16,
                 # HPAI -------------------------------------
                 @hpai_structure_length::8,
                 protocol_code(:udp)::8,
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
                 @ets_discovery_endpoint,
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
              {@ets_control_endpoint,
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
                 @ets_control_endpoint,
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
              {@ets_control_endpoint,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:connect_resp)::16,
                 @total_length_connect_resp_tunneling::16,
                 255::8,
                 connect_response_status_code(:no_error)::8,
                 @hpai_structure_length::8,
                 protocol_code(:udp)::8,
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
                 @ets_control_endpoint,
                 @connect_req_tunneling
               },
               %S{}
             )

    assert [
             {:ethernet, :transmit,
              {@ets_control_endpoint,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:connect_resp)::16,
                 @total_length_connect_resp_management::16,
                 1::8,
                 connect_response_status_code(:no_error)::8,
                 @hpai_structure_length::8,
                 protocol_code(:udp)::8,
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
                 @ets_control_endpoint,
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
              {@ets_control_endpoint,
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
                 @ets_control_endpoint,
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
              {@ets_control_endpoint,
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
                 @ets_control_endpoint,
                 @disconnect_req
               },
               %S{}
             )
  end

  ## Device Configuration Request:
  @device_configuration_req <<0x0610_0310_0011_04FE_0000_FC00_0001_5310_01::unit(8)-size(17)>>

  test("device configuration request") do
    assert [
             {:ethernet, :transmit,
              {@ets_config_data_endpoint,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:device_configuration_ack)::16,
                 10::16,
                 4::8,
                 254::8,
                 0::8,
                 device_configuration_ack_status_code(:no_error)::8
               >>}},
             {:ethernet, :transmit,
              {@ets_config_data_endpoint,
               <<
                 @header_size::8,
                 @protocol_version::8,
                 service_type_id(:device_configuration_req)::16,
                 19::16,
                 4::8,
                 254::8,
                 0::8,
                 0::8,
                 cemi_message_code(:m_propread_con)::8,
                 0::16,
                 1::8,
                 83::8,
                 1::4,
                 1::12,
                 0x07B0::16
               >>}}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ets_config_data_endpoint,
                 @device_configuration_req
               },
               %S{}
             )
  end

  # Tunneling Req:
  @tunneling_req_group_value_write <<0x0610_0420_0015_04FF_0000_2900_BCE0_2102_0001_0100_81::unit(
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

  ## Tunneling Ack:
  # KNXnet/IP Header -----------------------------------------------------------
  @service_type_id_tunneling_ack 0x0421
  @total_length 0x000A
  # Connection Header ----------------------------------------------------------
  @structure_length_connection_header 0x04
  @channel_id 0xFF
  @ext_seq_counter 0x00
  @status 0x00

  test "tunneling request, group value write" do

    # open tunneling connection first
    Ip.handle(
      {
        :ip,
        :from_ip,
        @ets_control_endpoint,
        @connect_req_tunneling
      },
      %S{}
    )

    assert [
             {:ethernet, :transmit,
              {@ets_tunneling_data_endpoint,
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
                eff: @eff
              }}
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ets_tunneling_data_endpoint,
                 @tunneling_req_group_value_write
               },
               %S{}
             )
  end
end
