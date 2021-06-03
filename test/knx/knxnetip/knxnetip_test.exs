defmodule Knx.Knxnetip.KnxNetIpTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Frame, as: F
  alias Knx.Knxnetip.IpInterface, as: Ip
  alias Knx.Knxnetip.Connection, as: C
  alias Knx.Knxnetip.Endpoint, as: Ep
  alias Knx.Knxnetip.ConTab

  require Knx.Defs
  import Knx.Defs

  # 192.168.178.62
  @ip_interface_ip 0xC0A8_B23E
  # 3671 (14, 87)
  @ip_interface_port 0x0E57

  @ip_interface_universal_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ip_interface_ip,
    port: @ip_interface_port
  }

  # 192.168.178.21
  @ets_ip 0xC0A8_B215

  # 60427
  @ets_port_discovery 0xEC0B
  # 52250
  @ets_port_control 0xCC1A
  # 52252
  @ets_port_config_data 0xCC1C
  # 52252
  @ets_port_tunnelling_data 0xCC1C

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

  @ets_tunnelling_data_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_tunnelling_data
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

  @total_length_search_resp structure_length(:header) + structure_length(:hpai) +
                              structure_length(:dib_device_info) +
                              structure_length(:dib_supp_svc_families)

  test "search request" do
    assert [
             {:ethernet, :transmit,
              {@ets_discovery_endpoint,
               <<
                 structure_length(:header)::8,
                 protocol_version(:knxnetip)::8,
                 service_type_id(:search_resp)::16,
                 @total_length_search_resp::16,
                 # HPAI -------------------------------------
                 structure_length(:hpai)::8,
                 protocol_code(:udp)::8,
                 @ip_interface_ip::32,
                 @ip_interface_port::16,
                 # DIB Device Info --------------------------
                 structure_length(:dib_device_info)::8,
                 description_type_code(:device_info)::8,
                 0x02::8,
                 1::8,
                 0x11FF::16,
                 0x0000::16,
                 0x112233445566::48,
                 0xE000170C::32,
                 0x000000000000::48,
                 0x4B4E_586E_6574_2F49_5020_4465_7669_6365_0000_0000_0000_0000_0000_0000_0000::unit(
                   8
                 )-size(30),
                 # DIB Supported Service Families ------------
                 structure_length(:dib_supp_svc_families)::8,
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

  @total_length_description_resp structure_length(:header) + structure_length(:dib_device_info) +
                                   structure_length(:dib_supp_svc_families)

  test "description request" do
    assert [
             {:ethernet, :transmit,
              {@ets_control_endpoint,
               <<
                 structure_length(:header)::8,
                 protocol_version(:knxnetip)::8,
                 service_type_id(:search_resp)::16,
                 @total_length_description_resp::16,
                 # DIB Device Info --------------------------
                 structure_length(:dib_device_info)::8,
                 description_type_code(:device_info)::8,
                 # TODO
                 0x02::8,
                 1::8,
                 0x11FF::16,
                 0x0000::16,
                 0x112233445566::48,
                 0xE000170C::32,
                 0x000000000000::48,
                 0x4B4E_586E_6574_2F49_5020_4465_7669_6365_0000_0000_0000_0000_0000_0000_0000::unit(
                   8
                 )-size(30),
                 # DIB Supported Service Families ------------
                 structure_length(:dib_supp_svc_families)::8,
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
  @connect_req_tunnelling <<0x0610_0205_001A_0801_C0A8_B215_CC1A_0801_C0A8_B215_CC1C_0404_0200::unit(
                              8
                            )-size(26)>>

  @connect_req_management <<0x0610_0205_0018_0801_C0A8_B215_CC1A_0801_C0A8_B215_CC1C_0203::unit(8)-size(
                              24
                            )>>

  @total_length_connect_resp_tunnelling structure_length(:header) + 2 + structure_length(:hpai) +
                                          4
  @total_length_connect_resp_management structure_length(:header) + 2 + structure_length(:hpai) +
                                          2
  # TODO
  @knx_indv_addr 0x11FF

  test("connect request") do
    assert [
             {:ethernet, :transmit,
              {@ets_control_endpoint,
               <<
                 structure_length(:header)::8,
                 protocol_version(:knxnetip)::8,
                 service_type_id(:connect_resp)::16,
                 @total_length_connect_resp_tunnelling::16,
                 255::8,
                 connect_response_status_code(:no_error)::8,
                 structure_length(:hpai)::8,
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
                 @connect_req_tunnelling
               },
               %S{}
             )

    assert [
             {:ethernet, :transmit,
              {@ets_control_endpoint,
               <<
                 structure_length(:header)::8,
                 protocol_version(:knxnetip)::8,
                 service_type_id(:connect_resp)::16,
                 @total_length_connect_resp_management::16,
                 1::8,
                 connect_response_status_code(:no_error)::8,
                 structure_length(:hpai)::8,
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

  @total_length_connectionstate_resp structure_length(:header) + 2

  test("connectionstate request") do
    assert [
             {:ethernet, :transmit,
              {@ets_control_endpoint,
               <<
                 structure_length(:header)::8,
                 protocol_version(:knxnetip)::8,
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

  @total_length_disconnect_resp structure_length(:header) + 2

  test("disconnect request") do
    assert [
             {:ethernet, :transmit,
              {@ets_control_endpoint,
               <<
                 structure_length(:header)::8,
                 protocol_version(:knxnetip)::8,
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
                 structure_length(:header)::8,
                 protocol_version(:knxnetip)::8,
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
                 structure_length(:header)::8,
                 protocol_version(:knxnetip)::8,
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

  ## Tunnelling Request, L_Data.req:
  @_1_tunnelling_req_l_data_req <<0x0610_0420_0019_04FF_0000_1100_B070_0000_2102_0547_D500_0B10_01::8*25>>
  @_1_knx_frame %F{
    data: <<0x47D5_000B_1001::8*6>>,
    prio: 0,
    src: @knx_indv_addr,
    dest: 0x2102,
    addr_t: 0,
    hops: 7
  }
  @_1_tunnelling_ack <<0x0610_0421_000A_04FF_0000::8*10>>
  @_1_tunnelling_req_l_data_con <<0x0610_0420_0019_04FF_0000_2E00_8070_11FF_2102_0547_D500_0B10_01::8*25>>

  test("tunnelling request, l_data.req") do
    # open tunnelling connection first
    Ip.handle(
      {
        :ip,
        :from_ip,
        @ets_control_endpoint,
        @connect_req_tunnelling
      },
      %S{}
    )

    assert [
             {:ethernet, :transmit, {@ets_tunnelling_data_endpoint, @_1_tunnelling_ack}},
             {:dl, :req, @_1_knx_frame},
             {:ethernet, :transmit,
              {@ets_tunnelling_data_endpoint, @_1_tunnelling_req_l_data_con}}
           ] =
             Ip.handle(
               {:ip, :from_ip, @ets_tunnelling_data_endpoint, @_1_tunnelling_req_l_data_req},
               %S{}
             )

    con_tab = Cache.get(:con_tab)
    assert 1 == ConTab.get_ext_seq_counter(con_tab, 0xFF)
  end

  ## Tunnelling ACK
  @_2_tunnelling_ack <<0x0610_0421_000A_04FF_0000::8*10>>

  test("tunnelling ack") do
    # open tunnelling connection first
    Ip.handle(
      {
        :ip,
        :from_ip,
        @ets_control_endpoint,
        @connect_req_tunnelling
      },
      %S{}
    )

    assert [] =
             Ip.handle(
               {:ip, :from_ip, @ip_interface_universal_endpoint, @_2_tunnelling_ack},
               %S{}
             )

    con_tab = Cache.get(:con_tab)
    assert 1 == ConTab.get_int_seq_counter(con_tab, 0xFF)
  end

  ## Tunnelling Request, L_Data.ind:
  @_3_knx_frame %F{
    prio: 0,
    addr_t: 0,
    hops: 7,
    src: 0x2102,
    dest: @knx_indv_addr,
    len: 0,
    data: <<0xC6>>
  }

  @_3_tunnelling_req_l_data_ind <<0x0610_0420_0014_04FF_0000_2900_8070_2102_11FF_00C6::8*20>>

  test("tunnelling request, l_data.ind") do
    # open tunnelling connection first
    Ip.handle(
      {
        :ip,
        :from_ip,
        @ets_control_endpoint,
        @connect_req_tunnelling
      },
      %S{}
    )

    assert [
             {:ethernet, :transmit,
              {@ets_tunnelling_data_endpoint, @_3_tunnelling_req_l_data_ind}}
           ] =
             Ip.handle(
               {:ip, :from_knx, @_3_knx_frame},
               %S{}
             )
  end
end
