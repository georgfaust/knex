defmodule Knx.KnxnetIp.KnxnetIpTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Frame, as: F
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.ConTab

  require Knx.Defs
  import Knx.Defs

  # 192.168.178.62
  @ip_interface_ip 0xC0A8_B23E
  # 3671 (14, 87)
  @ip_interface_port 0x0E57

  # 192.168.178.21
  @ets_ip 0xC0A8_B215

  # 60427
  @ets_port_discovery 0xEC0B
  # 52250
  @ets_port_control 0xCC1A
  # 52252
  @ets_port_device_mgmt_data 0xCC1C
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

  @ets_device_mgmt_data_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_device_mgmt_data
  }

  @ets_tunnelling_data_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_tunnelling_data
  }

  @device_object Helper.get_device_props(1)
  @knxnet_ip_parameter_object Helper.get_knxnetip_parameter_props()

  @knx_medium 0x02
  @device_status 1
  @knx_indv_addr 0x11FF
  @project_installation_id 0x0000
  @serial 0x112233445566
  @multicast_addr 0xE000170C
  @mac_addr 0x000000000000
  @friendly_name 0x4B4E_586E_6574_2F49_5020_4465_7669_6365_0000_0000_0000_0000_0000_0000_0000

  @con_0 %C{id: 0, con_type: :device_mgmt_con, dest_data_endpoint: @ets_device_mgmt_data_endpoint}
  @con_255 %C{
    id: 255,
    con_type: :tunnel_con,
    dest_data_endpoint: @ets_tunnelling_data_endpoint
  }

  setup do
    Cache.start_link(%{
      objects: [device: @device_object, knxnet_ip_parameter: @knxnet_ip_parameter_object],
      con_tab: %{
        :free_mgmt_ids => Enum.to_list(1..254),
        0 => @con_0
      }
    })

    :timer.sleep(5)
    :ok
  end

  # ----------------------------------------------------------------------------
  describe "search request" do
    @total_length_search_resp structure_length(:header) + structure_length(:hpai) +
                                structure_length(:dib_device_info) +
                                structure_length(:dib_supp_svc_families)
    test "successful" do
      assert [
               {:ethernet, :transmit,
                {@ets_discovery_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:search_resp)::16,
                   @total_length_search_resp::16,
                   # HPAI ------------------------------------------------------
                   structure_length(:hpai)::8,
                   protocol_code(:udp)::8,
                   @ip_interface_ip::32,
                   @ip_interface_port::16,
                   # DIB Device Info -------------------------------------------
                   structure_length(:dib_device_info)::8,
                   description_type_code(:device_info)::8,
                   @knx_medium::8,
                   @device_status::8,
                   @knx_indv_addr::16,
                   @project_installation_id::16,
                   @serial::48,
                   @multicast_addr::32,
                   @mac_addr::48,
                   @friendly_name::8*30,
                   # DIB Supported Service Families ----------------------------
                   structure_length(:dib_supp_svc_families)::8,
                   description_type_code(:supp_svc_families)::8,
                   service_family_id(:core)::8,
                   protocol_version(:core)::8,
                   service_family_id(:device_management)::8,
                   protocol_version(:device_management)::8,
                   service_family_id(:tunnelling)::8,
                   protocol_version(:tunnelling)::8
                 >>}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_discovery_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:search_req)::16,
                     structure_length(:header) + structure_length(:hpai)::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_discovery::16
                   >>
                 },
                 %S{}
               )
    end
  end

  # ----------------------------------------------------------------------------
  describe "description request" do
    @total_length_description_resp structure_length(:header) + structure_length(:dib_device_info) +
                                     structure_length(:dib_supp_svc_families)

    test "successful" do
      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:description_resp)::16,
                   @total_length_description_resp::16,
                   # DIB Device Info -------------------------------------------
                   structure_length(:dib_device_info)::8,
                   description_type_code(:device_info)::8,
                   @knx_medium::8,
                   @device_status::8,
                   @knx_indv_addr::16,
                   @project_installation_id::16,
                   @serial::48,
                   @multicast_addr::32,
                   @mac_addr::48,
                   @friendly_name::8*30,
                   # DIB Supported Service Families ----------------------------
                   structure_length(:dib_supp_svc_families)::8,
                   description_type_code(:supp_svc_families)::8,
                   service_family_id(:core)::8,
                   protocol_version(:core)::8,
                   service_family_id(:device_management)::8,
                   protocol_version(:device_management)::8,
                   service_family_id(:tunnelling)::8,
                   protocol_version(:tunnelling)::8
                 >>}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:description_req)::16,
                     structure_length(:header) + structure_length(:hpai)::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16
                   >>
                 },
                 %S{}
               )
    end
  end

  # ----------------------------------------------------------------------------
  describe "connect request" do
    @total_length_connect_resp_management structure_length(:header) + 2 + structure_length(:hpai) +
                                            2
    @total_length_connect_resp_tunnelling structure_length(:header) + 2 + structure_length(:hpai) +
                                            4

    @total_length_connect_resp_management structure_length(:header) +
                                            connection_header_structure_length(:core) +
                                            structure_length(:hpai) +
                                            crd_structure_length(:device_mgmt_con)
    @total_length_connect_resp_tunnelling structure_length(:header) +
                                            connection_header_structure_length(:core) +
                                            structure_length(:hpai) +
                                            crd_structure_length(:tunnel_con)
    @total_length_connect_resp_error structure_length(:header) + 1

    test "device management, successful" do
      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:connect_resp)::16,
                   @total_length_connect_resp_management::16,
                   # Connection Header -----------------------------------------
                   1::8,
                   connect_response_status_code(:no_error)::8,
                   # HPAI ------------------------------------------------------
                   structure_length(:hpai)::8,
                   protocol_code(:udp)::8,
                   @ip_interface_ip::32,
                   @ip_interface_port::16,
                   # CRD -------------------------------------------------------
                   crd_structure_length(:device_mgmt_con)::8,
                   con_type_code(:device_mgmt_con)::8
                 >>}},
               {:timer, :start, {:ip_connection, 1}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:connect_req)::16,
                     structure_length(:header) + 2 * structure_length(:hpai) +
                       crd_structure_length(:device_mgmt_con)::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_device_mgmt_data::16,
                     # CRI -----------------------------------------------------
                     cri_structure_length(:device_mgmt_con)::8,
                     con_type_code(:device_mgmt_con)::8
                   >>
                 },
                 %S{}
               )
    end

    test "device management, error: no_more_connections" do
      Cache.put(:con_tab, %{
        :free_mgmt_ids => []
      })

      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:connect_resp)::16,
                   @total_length_connect_resp_error::16,
                   connect_response_status_code(:no_more_connections)::8
                 >>}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:connect_req)::16,
                     structure_length(:header) + 2 * structure_length(:hpai) +
                       crd_structure_length(:device_mgmt_con)::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_device_mgmt_data::16,
                     # CRI -----------------------------------------------------
                     cri_structure_length(:device_mgmt_con)::8,
                     con_type_code(:device_mgmt_con)::8
                   >>
                 },
                 %S{}
               )
    end

    test "tunnelling, successful" do
      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:connect_resp)::16,
                   @total_length_connect_resp_tunnelling::16,
                   # Connection Header -----------------------------------------
                   255::8,
                   connect_response_status_code(:no_error)::8,
                   # HPAI ------------------------------------------------------
                   structure_length(:hpai)::8,
                   protocol_code(:udp)::8,
                   @ip_interface_ip::32,
                   @ip_interface_port::16,
                   # CRD -------------------------------------------------------
                   crd_structure_length(:tunnel_con)::8,
                   con_type_code(:tunnel_con)::8,
                   @knx_indv_addr::16
                 >>}},
               {:timer, :start, {:ip_connection, 255}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:connect_req)::16,
                     structure_length(:header) + 2 * structure_length(:hpai) +
                       crd_structure_length(:tunnel_con)::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_tunnelling_data::16,
                     # CRI -----------------------------------------------------
                     cri_structure_length(:tunnel_con)::8,
                     con_type_code(:tunnel_con)::8,
                     tunnelling_knx_layer(:tunnel_linklayer)::8,
                     knxnetip_constant(:reserved)::8
                   >>
                 },
                 %S{}
               )
    end

    test "tunnelling, error: no_more_connections" do
      Cache.put(:con_tab, %{
        255 => %C{
          id: 255,
          con_type: :tunnel_con,
          dest_data_endpoint: @ets_tunnelling_data_endpoint
        }
      })

      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:connect_resp)::16,
                   @total_length_connect_resp_error::16,
                   connect_response_status_code(:no_more_connections)::8
                 >>}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:connect_req)::16,
                     structure_length(:header) + 2 * structure_length(:hpai) +
                       crd_structure_length(:tunnel_con)::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_tunnelling_data::16,
                     # CRI -----------------------------------------------------
                     cri_structure_length(:tunnel_con)::8,
                     con_type_code(:tunnel_con)::8,
                     tunnelling_knx_layer(:tunnel_linklayer)::8,
                     knxnetip_constant(:reserved)::8
                   >>
                 },
                 %S{}
               )
    end

    test "tunnelling, error: connection_option" do
      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:connect_resp)::16,
                   @total_length_connect_resp_error::16,
                   connect_response_status_code(:connection_option)::8
                 >>}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:connect_req)::16,
                     structure_length(:header) + 2 * structure_length(:hpai) +
                       crd_structure_length(:tunnel_con)::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_tunnelling_data::16,
                     # CRI -----------------------------------------------------
                     cri_structure_length(:tunnel_con)::8,
                     con_type_code(:tunnel_con)::8,
                     tunnelling_knx_layer(:tunnel_raw)::8,
                     knxnetip_constant(:reserved)::8
                   >>
                 },
                 %S{}
               )
    end

    test "error: connection_type" do
      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:connect_resp)::16,
                   @total_length_connect_resp_error::16,
                   connect_response_status_code(:connection_type)::8
                 >>}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:connect_req)::16,
                     structure_length(:header) + 2 * structure_length(:hpai) +
                       crd_structure_length(:tunnel_con)::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_tunnelling_data::16,
                     # CRI -----------------------------------------------------
                     cri_structure_length(:tunnel_con)::8,
                     con_type_code(:remlog_con)::8,
                     tunnelling_knx_layer(:tunnel_linklayer)::8,
                     knxnetip_constant(:reserved)::8
                   >>
                 },
                 %S{}
               )
    end
  end

  # ----------------------------------------------------------------------------
  describe "connectionstate request" do
    @total_length_connectionstate_resp structure_length(:header) +
                                         connection_header_structure_length(:core)

    test "successful" do
      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:connectionstate_resp)::16,
                   @total_length_connectionstate_resp::16,
                   # Connection Header -----------------------------------------
                   0::8,
                   connectionstate_response_status_code(:no_error)::8
                 >>}},
               {:timer, :restart, {:ip_connection, 0}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:connectionstate_req)::16,
                     structure_length(:header) + connection_header_structure_length(:core) +
                       structure_length(:hpai)::16,
                     # Connection Header ---------------------------------------
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16
                   >>
                 },
                 %S{}
               )
    end

    test "error: connection_id" do
      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:connectionstate_resp)::16,
                   @total_length_connectionstate_resp::16,
                   # Connection Header -----------------------------------------
                   1::8,
                   connectionstate_response_status_code(:connection_id)::8
                 >>}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:connectionstate_req)::16,
                     structure_length(:header) + connection_header_structure_length(:core) +
                       structure_length(:hpai)::16,
                     # Connection Header ---------------------------------------
                     1::8,
                     knxnetip_constant(:reserved)::8,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16
                   >>
                 },
                 %S{}
               )
    end
  end

  # ----------------------------------------------------------------------------
  describe "disconnect request" do
    @total_length_disconnect_resp structure_length(:header) +
                                    connection_header_structure_length(:core)
    test "successful" do
      assert [
               {:ethernet, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:disconnect_resp)::16,
                   @total_length_disconnect_resp::16,
                   # Connection Header -----------------------------------------
                   0::8,
                   common_error_code(:no_error)::8
                 >>}},
               {:timer, :stop, {:ip_connection, 0}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:disconnect_req)::16,
                     structure_length(:header) + connection_header_structure_length(:core) +
                       structure_length(:hpai)::16,
                     # Connection Header ---------------------------------------
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16
                   >>
                 },
                 %S{}
               )
    end

    test "error: connection does not exist" do
      assert [] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_control_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:disconnect_req)::16,
                     structure_length(:header) + connection_header_structure_length(:core) +
                       structure_length(:hpai)::16,
                     # Connection Header ---------------------------------------
                     1::8,
                     knxnetip_constant(:reserved)::8,
                     # HPAI ----------------------------------------------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ets_ip::32,
                     @ets_port_control::16
                   >>
                 },
                 %S{}
               )
    end
  end

  # ----------------------------------------------------------------------------
  describe "device configuration request" do
    @total_length_device_config_ack structure_length(:header) +
                                      connection_header_structure_length(:device_management)
    @total_length_device_config_req structure_length(:header) +
                                      connection_header_structure_length(:device_management) + 9
    @total_length_device_config_req_error_prop_read structure_length(:header) +
                                                      connection_header_structure_length(
                                                        :device_management
                                                      ) + 8

    test "m_propread.req, successful" do
      assert [
               {:timer, :restart, {:ip_connection, 0}},
               {:ethernet, :transmit,
                {@ets_device_mgmt_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:device_configuration_ack)::16,
                   @total_length_device_config_ack::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:device_management)::8,
                   0::8,
                   0::8,
                   common_error_code(:no_error)::8
                 >>}},
               {:ethernet, :transmit,
                {@ets_device_mgmt_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:device_configuration_req)::16,
                   @total_length_device_config_req::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:device_management)::8,
                   0::8,
                   0::8,
                   knxnetip_constant(:reserved)::8,
                   # cEMI ------------------------------------------------------
                   cemi_message_code(:m_propread_con)::8,
                   0::16,
                   1::8,
                   0x53::8,
                   1::4,
                   1::12,
                   0x07B0::16
                 >>}},
               {:timer, :start, {:device_management_req, 0}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_device_mgmt_data_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:device_configuration_req)::16,
                     structure_length(:header) +
                       connection_header_structure_length(:device_management) + 7::16,
                     # Connection header ---------------------------------------
                     connection_header_structure_length(:device_management)::8,
                     0::8,
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # cEMI ----------------------------------------------------
                     cemi_message_code(:m_propread_req)::8,
                     0::16,
                     1::8,
                     0x53::8,
                     1::4,
                     1::12
                   >>
                 },
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 1 == ConTab.get_client_seq_counter(con_tab, 0x00)
    end

    test "m_propread.req, error: property read" do
      assert [
               {:timer, :restart, {:ip_connection, 0}},
               {:ethernet, :transmit,
                {@ets_device_mgmt_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:device_configuration_ack)::16,
                   @total_length_device_config_ack::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:device_management)::8,
                   0::8,
                   0::8,
                   common_error_code(:no_error)::8
                 >>}},
               {:ethernet, :transmit,
                {@ets_device_mgmt_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:device_configuration_req)::16,
                   @total_length_device_config_req_error_prop_read::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:device_management)::8,
                   0::8,
                   0::8,
                   knxnetip_constant(:reserved)::8,
                   # cEMI ------------------------------------------------------
                   cemi_message_code(:m_propread_con)::8,
                   0::16,
                   2::8,
                   0x99::8,
                   0::4,
                   1::12,
                   cemi_error_code(:unspecific)
                 >>}},
               {:timer, :start, {:device_management_req, 0}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_device_mgmt_data_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:device_configuration_req)::16,
                     structure_length(:header) +
                       connection_header_structure_length(:device_management) + 7::16,
                     # Connection header ---------------------------------------
                     connection_header_structure_length(:device_management)::8,
                     0::8,
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # cEMI ----------------------------------------------------
                     cemi_message_code(:m_propread_req)::8,
                     0::16,
                     2::8,
                     0x99::8,
                     1::4,
                     1::12
                   >>
                 },
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 1 == ConTab.get_client_seq_counter(con_tab, 0x00)
    end

    test "m_propread.con" do
      assert [
               {:timer, :restart, {:ip_connection, 0}},
               {:ethernet, :transmit,
                {@ets_device_mgmt_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:device_configuration_ack)::16,
                   @total_length_device_config_ack::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:device_management)::8,
                   0::8,
                   0::8,
                   common_error_code(:no_error)::8
                 >>}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_device_mgmt_data_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:device_configuration_req)::16,
                     structure_length(:header) +
                       connection_header_structure_length(:device_management) + 7::16,
                     # Connection header ---------------------------------------
                     connection_header_structure_length(:device_management)::8,
                     0::8,
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # cEMI ----------------------------------------------------
                     cemi_message_code(:m_propread_con)::8,
                     0::16,
                     1::8,
                     0x53::8,
                     1::4,
                     1::12,
                     0::8
                   >>
                 },
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 1 == ConTab.get_client_seq_counter(con_tab, 0x00)
    end

    test "error: connection does not exist" do
      assert [] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_device_mgmt_data_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:device_configuration_req)::16,
                     structure_length(:header) +
                       connection_header_structure_length(:device_management) + 7::16,
                     # Connection header ---------------------------------------
                     connection_header_structure_length(:device_management)::8,
                     1::8,
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # cEMI ----------------------------------------------------
                     cemi_message_code(:m_propread_req)::8,
                     0::16,
                     1::8,
                     0x53::8,
                     1::4,
                     1::12
                   >>
                 },
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 0 == ConTab.get_client_seq_counter(con_tab, 0x00)
    end
  end

  # ----------------------------------------------------------------------------
  describe "device configuration ack" do
    @total_length_device_config_ack structure_length(:header) +
                                      connection_header_structure_length(:device_management)
    test "successful" do
      assert [
               {:timer, :restart, {:ip_connection, 0}},
               {:timer, :stop, {:device_management_req, 0}}
             ] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_device_mgmt_data_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:device_configuration_ack)::16,
                     @total_length_device_config_ack::16,
                     # Connection header ---------------------------------------
                     connection_header_structure_length(:device_management)::8,
                     0::8,
                     0::8,
                     common_error_code(:no_error)::8
                   >>
                 },
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 1 == ConTab.get_server_seq_counter(con_tab, 0x00)
    end

    test "error: connection id does not exist" do
      assert [] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_device_mgmt_data_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:device_configuration_ack)::16,
                     @total_length_device_config_ack::16,
                     # Connection header ---------------------------------------
                     connection_header_structure_length(:device_management)::8,
                     99::8,
                     0::8,
                     common_error_code(:no_error)::8
                   >>
                 },
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 0 == ConTab.get_server_seq_counter(con_tab, 0x00)
    end

    test "error: sequence counter wrong" do
      assert [] =
               Ip.handle(
                 {
                   :ip,
                   :from_ip,
                   @ets_device_mgmt_data_endpoint,
                   <<
                     # Header --------------------------------------------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_type_id(:device_configuration_ack)::16,
                     @total_length_device_config_ack::16,
                     # Connection header ---------------------------------------
                     connection_header_structure_length(:device_management)::8,
                     0::8,
                     23::8,
                     common_error_code(:no_error)::8
                   >>
                 },
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 0 == ConTab.get_server_seq_counter(con_tab, 0x00)
    end
  end

  # ----------------------------------------------------------------------------
  describe "tunnelling request" do
    @knx_frame_tunnelling_req_l_data_req %F{
      data: <<0x47D5_000B_1001::8*6>>,
      prio: 0,
      src: @knx_indv_addr,
      dest: 0x2102,
      addr_t: 0,
      hops: 7
    }
    @total_length_tunneling_ack structure_length(:header) +
                                  connection_header_structure_length(:tunnelling)
    @total_length_tunneling_req_l_data_con structure_length(:header) +
                                             connection_header_structure_length(:tunnelling) + 15

    test("l_data.req, expected seq counter") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:ethernet, :transmit,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:tunnelling_ack)::16,
                   @total_length_tunneling_ack::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:tunnelling)::8,
                   255::8,
                   0::8,
                   common_error_code(:no_error)::8
                 >>}},
               {:dl, :req, @knx_frame_tunnelling_req_l_data_req},
               {:ethernet, :transmit,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:tunnelling_req)::16,
                   @total_length_tunneling_req_l_data_con::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:tunnelling),
                   255::8,
                   0::8,
                   knxnetip_constant(:reserved)::8,
                   # cEMI ------------------------------------------------------
                   cemi_message_code(:l_data_con)::8,
                   0::8,
                   1::1,
                   0::1,
                   0::1,
                   0::1,
                   0::2,
                   0::1,
                   0::1,
                   0::1,
                   7::3,
                   0::4,
                   @knx_indv_addr::16,
                   0x2102::16,
                   0x05::8,
                   0x47D5_000B_1001::48
                 >>}},
               {:timer, :restart, {:ip_connection, 255}}
             ] =
               Ip.handle(
                 {:ip, :from_ip, @ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------------------------------------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_type_id(:tunnelling_req)::16,
                    structure_length(:header) + connection_header_structure_length(:tunnelling) +
                      15::16,
                    # Connection header ----------------------------------------
                    connection_header_structure_length(:tunnelling),
                    255::8,
                    0::8,
                    knxnetip_constant(:reserved)::8,
                    # cEMI -----------------------------------------------------
                    cemi_message_code(:l_data_req)::8,
                    0::8,
                    1::1,
                    0::1,
                    1::1,
                    1::1,
                    0::2,
                    0::1,
                    0::1,
                    0::1,
                    7::3,
                    0::4,
                    0x0000::16,
                    0x2102::16,
                    0x05::8,
                    0x47D5_000B_1001::48
                  >>},
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 1 == ConTab.get_client_seq_counter(con_tab, 0xFF)
    end

    test("l_data.req, error: expected seq counter - 1") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:ethernet, :transmit,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:tunnelling_ack)::16,
                   @total_length_tunneling_ack::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:tunnelling)::8,
                   255::8,
                   255::8,
                   common_error_code(:no_error)::8
                 >>}}
             ] =
               Ip.handle(
                 {:ip, :from_ip, @ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------------------------------------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_type_id(:tunnelling_req)::16,
                    structure_length(:header) + connection_header_structure_length(:tunnelling) +
                      15::16,
                    # Connection header ----------------------------------------
                    connection_header_structure_length(:tunnelling),
                    255::8,
                    255::8,
                    knxnetip_constant(:reserved)::8,
                    # cEMI -----------------------------------------------------
                    cemi_message_code(:l_data_req)::8,
                    0::8,
                    1::1,
                    0::1,
                    1::1,
                    1::1,
                    0::2,
                    0::1,
                    0::1,
                    0::1,
                    7::3,
                    0::4,
                    0x0000::16,
                    0x2102::16,
                    0x05::8,
                    0x47D5_000B_1001::48
                  >>},
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 0 == ConTab.get_client_seq_counter(con_tab, 0xFF)
    end

    test("l_data.req, error: wrong seq counter") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [] =
               Ip.handle(
                 {:ip, :from_ip, @ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------------------------------------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_type_id(:tunnelling_req)::16,
                    structure_length(:header) + connection_header_structure_length(:tunnelling) +
                      15::16,
                    # Connection header ----------------------------------------
                    connection_header_structure_length(:tunnelling),
                    255::8,
                    66::8,
                    knxnetip_constant(:reserved)::8,
                    # cEMI -----------------------------------------------------
                    cemi_message_code(:l_data_req)::8,
                    0::8,
                    1::1,
                    0::1,
                    1::1,
                    1::1,
                    0::2,
                    0::1,
                    0::1,
                    0::1,
                    7::3,
                    0::4,
                    0x0000::16,
                    0x2102::16,
                    0x05::8,
                    0x47D5_000B_1001::48
                  >>},
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 0 == ConTab.get_client_seq_counter(con_tab, 0xFF)
    end
  end

  # ----------------------------------------------------------------------------
  describe "tunnelling ack" do
    test("successful") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:timer, :restart, {:ip_connection, 255}},
               {:timer, :stop, {:device_management_req, 0}}
             ] =
               Ip.handle(
                 {:ip, :from_ip, @ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------------------------------------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_type_id(:tunnelling_ack)::16,
                    structure_length(:header) +
                      connection_header_structure_length(:tunnelling)::16,
                    # Connection header ----------------------------------------
                    connection_header_structure_length(:tunnelling)::8,
                    255::8,
                    0::8,
                    common_error_code(:no_error)::8
                  >>},
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 1 == ConTab.get_server_seq_counter(con_tab, 0xFF)
    end

    test("error: wrong seq counter") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [] =
               Ip.handle(
                 {:ip, :from_ip, @ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------------------------------------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_type_id(:tunnelling_ack)::16,
                    structure_length(:header) +
                      connection_header_structure_length(:tunnelling)::16,
                    # Connection header ----------------------------------------
                    connection_header_structure_length(:tunnelling)::8,
                    255::8,
                    23::8,
                    common_error_code(:no_error)::8
                  >>},
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 0 == ConTab.get_server_seq_counter(con_tab, 0xFF)
    end

    test("error: connection id does not exist") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [] =
               Ip.handle(
                 {:ip, :from_ip, @ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------------------------------------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_type_id(:tunnelling_ack)::16,
                    structure_length(:header) +
                      connection_header_structure_length(:tunnelling)::16,
                    # Connection header ----------------------------------------
                    connection_header_structure_length(:tunnelling)::8,
                    56::8,
                    0::8,
                    common_error_code(:no_error)::8
                  >>},
                 %S{}
               )

      con_tab = Cache.get(:con_tab)
      assert 0 == ConTab.get_server_seq_counter(con_tab, 0xFF)
    end
  end

  # ----------------------------------------------------------------------------
  describe "knx frame" do
    @knx_frame %F{
      prio: 0,
      addr_t: 0,
      hops: 7,
      src: 0x2102,
      dest: @knx_indv_addr,
      len: 0,
      data: <<0xC6>>
    }

    @total_length_tunnelling_req_l_data_ind structure_length(:header) +
                                              connection_header_structure_length(:tunnelling) + 10
    test("successful") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:ethernet, :transmit,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_type_id(:tunnelling_req)::16,
                   @total_length_tunnelling_req_l_data_ind::16,
                   # Connection header -----------------------------------------
                   connection_header_structure_length(:tunnelling)::8,
                   255::8,
                   0::8,
                   knxnetip_constant(:reserved)::8,
                   # cEMI ------------------------------------------------------
                   cemi_message_code(:l_data_ind)::8,
                   0::8,
                   1::1,
                   0::1,
                   0::1,
                   0::1,
                   0::2,
                   0::1,
                   0::1,
                   0::1,
                   7::3,
                   0::4,
                   0x2102::16,
                   @knx_indv_addr::16,
                   0x00::8,
                   0xC6::8
                 >>}},
               {:timer, :start, {:tunneling_req, 0}}
             ] =
               Ip.handle(
                 {:ip, :from_knx, @knx_frame},
                 %S{}
               )
    end
  end
end
