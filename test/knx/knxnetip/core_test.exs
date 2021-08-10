defmodule Knx.KnxnetIp.CoreTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.KnxnetIpParameter

  require Knx.Defs
  import Knx.Defs

  @ip_interface_ip Application.get_env(:knx, :ip_addr, {0, 0, 0, 0})
  @ip_interface_ip_num Helper.convert_ip_to_number(@ip_interface_ip)
  @ip_interface_port 3671

  @ets_ip {192, 168, 178, 21}
  @ets_ip_num Helper.convert_ip_to_number(@ets_ip)
  @ets_port_discovery 60427
  @ets_port_control 52250
  @ets_port_device_mgmt_data 52252
  @ets_port_tunnelling_data 52252

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
  @knxnet_ip_parameter_object KnxnetIpParameter.get_knxnetip_parameter_props()

  @knx_medium knx_medium_code(Application.get_env(:knx, :knx_medium, :tp1))
  @device_status 1
  @knx_indv_addr Application.get_env(:knx, :knx_addr, 0x1101)
  @project_installation_id 0x0000
  @serial 0x112233445566
  @multicast_addr 0xE000170C
  @mac_addr Application.get_env(:knx, :mac_addr, 0x000000000000)
  @friendly_name Application.get_env(:knx, :friendly_name, "empty name (KNXnet/IP)")
                 |> KnxnetIpParameter.convert_friendly_name()

  @list_0_255 Enum.to_list(0..255)
  @list_1_255 Enum.to_list(1..255)
  @list_2_255 Enum.to_list(2..255)

  @con_mgmt %C{
    id: 0,
    con_type: :device_mgmt_con,
    dest_control_endpoint: @ets_control_endpoint,
    dest_data_endpoint: @ets_device_mgmt_data_endpoint,
    con_knx_indv_addr: @knx_indv_addr,
    client_seq_counter: 0,
    server_seq_counter: 0
  }

  @con_tunnel %C{
    id: 1,
    con_type: :tunnel_con,
    dest_control_endpoint: @ets_control_endpoint,
    dest_data_endpoint: @ets_tunnelling_data_endpoint,
    con_knx_indv_addr: @knx_indv_addr,
    client_seq_counter: 0,
    server_seq_counter: 0
  }

  @con_tab %{
    :free_ids => @list_0_255,
    :tunnel_cons_left => 1
  }

  @con_tab_0 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{},
    :tunnel_cons_left => 1,
    0 => @con_mgmt
  }

  @con_tab_1 %{
    :free_ids => @list_2_255,
    :tunnel_cons => %{@knx_indv_addr => 1},
    :tunnel_cons_left => 0,
    0 => @con_mgmt,
    1 => @con_tunnel
  }

  @con_tab_full %{
    :free_ids => []
  }

  setup do
    Cache.start_link(%{
      objects: [device: @device_object, knxnet_ip_parameter: @knxnet_ip_parameter_object]
    })

    :timer.sleep(5)
    :ok
  end

  # ---------------
  describe "search request" do
    @total_length_search_resp Ip.get_structure_length([
                                :header,
                                :hpai,
                                :dib_device_info,
                                :dib_supp_svc_families
                              ])
    test "successful" do
      assert {
               %S{},
               [
                 {:ip, :transmit,
                  {@ets_discovery_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:search_resp)::8,
                     @total_length_search_resp::16,
                     # HPAI ---------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ip_interface_ip_num::32,
                     @ip_interface_port::16,
                     # DIB Device Info ---------------
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
                     # DIB Supported Service Families ---------------
                     structure_length(:dib_supp_svc_families)::8,
                     description_type_code(:supp_svc_families)::8,
                     service_family_id(:core)::8,
                     protocol_version(:core)::8,
                     service_family_id(:device_management)::8,
                     protocol_version(:device_management)::8,
                     service_family_id(:tunnelling)::8,
                     protocol_version(:tunnelling)::8
                   >>}}
               ]
             } =
               Ip.handle(
                 {
                   :knip,
                   :from_ip,
                   {@ets_discovery_endpoint,
                    <<
                      # Header ---------------
                      structure_length(:header)::8,
                      protocol_version(:knxnetip)::8,
                      service_family_id(:core)::8,
                      service_type_id(:search_req)::8,
                      Ip.get_structure_length([:header, :hpai])::16,
                      # HPAI ---------------
                      structure_length(:hpai)::8,
                      protocol_code(:udp)::8,
                      @ets_ip_num::32,
                      @ets_port_discovery::16
                    >>}
                 },
                 %S{}
               )
    end
  end

  # ---------------
  describe "description request" do
    @total_length_description_resp Ip.get_structure_length([
                                     :header,
                                     :dib_device_info,
                                     :dib_supp_svc_families
                                   ])

    test "successful" do
      assert {
               %S{},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:description_resp)::8,
                     @total_length_description_resp::16,
                     # DIB Device Info ---------------
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
                     # DIB Supported Service Families ---------------
                     structure_length(:dib_supp_svc_families)::8,
                     description_type_code(:supp_svc_families)::8,
                     service_family_id(:core)::8,
                     protocol_version(:core)::8,
                     service_family_id(:device_management)::8,
                     protocol_version(:device_management)::8,
                     service_family_id(:tunnelling)::8,
                     protocol_version(:tunnelling)::8
                   >>}}
               ]
             } =
               Ip.handle(
                 {
                   :knip,
                   :from_ip,
                   {@ets_control_endpoint,
                    <<
                      # Header ---------------
                      structure_length(:header)::8,
                      protocol_version(:knxnetip)::8,
                      service_family_id(:core)::8,
                      service_type_id(:description_req)::8,
                      Ip.get_structure_length([:header, :hpai])::16,
                      # HPAI ---------------
                      structure_length(:hpai)::8,
                      protocol_code(:udp)::8,
                      @ets_ip_num::32,
                      @ets_port_control::16
                    >>}
                 },
                 %S{}
               )
    end
  end

  # ---------------
  describe "connect request" do
    @total_length_connect_resp_management Ip.get_structure_length([
                                            :header,
                                            :connection_header_core,
                                            :hpai,
                                            :crd_device_mgmt_con
                                          ])

    @total_length_connect_resp_tunnelling Ip.get_structure_length([
                                            :header,
                                            :connection_header_core,
                                            :hpai,
                                            :crd_tunnel_con
                                          ])
    @total_length_connect_resp_error structure_length(:header) + 1

    def receive_connect_req_device_management(%S{} = state) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_control_endpoint,
           <<
             # Header ---------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:core)::8,
             service_type_id(:connect_req)::8,
             Ip.get_structure_length([
               :header,
               :hpai,
               :hpai,
               :crd_device_mgmt_con
             ])::16,
             # HPAI ---------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip_num::32,
             @ets_port_control::16,
             # HPAI ---------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip_num::32,
             @ets_port_device_mgmt_data::16,
             # CRI ---------------
             structure_length(:crd_device_mgmt_con)::8,
             con_type_code(:device_mgmt_con)::8
           >>}
        },
        state
      )
    end

    def receive_connect_req_tunnelling(
          %S{} = state,
          con_type: con_type,
          tunnelling_knx_layer: tunnelling_knx_layer
        ) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_control_endpoint,
           <<
             # Header ---------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:core)::8,
             service_type_id(:connect_req)::8,
             Ip.get_structure_length([
               :header,
               :hpai,
               :hpai,
               :crd_tunnel_con
             ])::16,
             # HPAI ---------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip_num::32,
             @ets_port_control::16,
             # HPAI ---------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip_num::32,
             @ets_port_tunnelling_data::16,
             # CRI ---------------
             structure_length(:cri_tunnel_con)::8,
             con_type_code(con_type)::8,
             tunnelling_knx_layer_code(tunnelling_knx_layer)::8,
             knxnetip_constant(:reserved)::8
           >>}
        },
        state
      )
    end

    test "device management, successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:connect_resp)::8,
                     @total_length_connect_resp_management::16,
                     # Connection Header ---------------
                     0::8,
                     connect_response_status_code(:no_error)::8,
                     # HPAI ---------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ip_interface_ip_num::32,
                     @ip_interface_port::16,
                     # CRD ---------------
                     structure_length(:crd_device_mgmt_con)::8,
                     con_type_code(:device_mgmt_con)::8
                   >>}},
                 {:timer, :start, {:ip_connection, 0}}
               ]
             } = receive_connect_req_device_management(%S{knxnetip: %IpState{con_tab: %{}}})
    end

    test "device management, error: no_more_connections" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_full}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:connect_resp)::8,
                     @total_length_connect_resp_error::16,
                     connect_response_status_code(:no_more_connections)::8
                   >>}}
               ]
             } =
               receive_connect_req_device_management(%S{
                 knxnetip: %IpState{con_tab: @con_tab_full}
               })
    end

    test "tunnelling, successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_1}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:connect_resp)::8,
                     @total_length_connect_resp_tunnelling::16,
                     # Connection Header ---------------
                     1::8,
                     connect_response_status_code(:no_error)::8,
                     # HPAI ---------------
                     structure_length(:hpai)::8,
                     protocol_code(:udp)::8,
                     @ip_interface_ip_num::32,
                     @ip_interface_port::16,
                     # CRD ---------------
                     structure_length(:crd_tunnel_con)::8,
                     con_type_code(:tunnel_con)::8,
                     @knx_indv_addr::16
                   >>}},
                 {:timer, :start, {:ip_connection, 1}}
               ]
             } =
               receive_connect_req_tunnelling(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 con_type: :tunnel_con,
                 tunnelling_knx_layer: :tunnel_linklayer
               )
    end

    test "tunnelling, error: no_more_connections" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_1}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:connect_resp)::8,
                     @total_length_connect_resp_error::16,
                     connect_response_status_code(:no_more_connections)::8
                   >>}}
               ]
             } =
               receive_connect_req_tunnelling(
                 %S{knxnetip: %IpState{con_tab: @con_tab_1}},
                 con_type: :tunnel_con,
                 tunnelling_knx_layer: :tunnel_linklayer
               )
    end

    test "tunnelling, error: connection_option" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:connect_resp)::8,
                     @total_length_connect_resp_error::16,
                     connect_response_status_code(:connection_option)::8
                   >>}}
               ]
             } =
               receive_connect_req_tunnelling(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 con_type: :tunnel_con,
                 tunnelling_knx_layer: :tunnel_raw
               )
    end

    test "error: connection_type" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:connect_resp)::8,
                     @total_length_connect_resp_error::16,
                     connect_response_status_code(:connection_type)::8
                   >>}}
               ]
             } =
               receive_connect_req_tunnelling(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 con_type: :remlog_con,
                 tunnelling_knx_layer: :tunnel_linklayer
               )
    end
  end

  # ---------------
  describe "connectionstate request" do
    @total_length_connectionstate_resp Ip.get_structure_length([
                                         :header,
                                         :connection_header_core
                                       ])

    def receive_connectionstate_req(%S{} = state, connection_id: connection_id) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_control_endpoint,
           <<
             # Header ---------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:core)::8,
             service_type_id(:connectionstate_req)::8,
             Ip.get_structure_length([
               :header,
               :connection_header_core,
               :hpai
             ])::16,
             # Connection Header ---------------
             connection_id::8,
             knxnetip_constant(:reserved)::8,
             # HPAI ---------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip_num::32,
             @ets_port_control::16
           >>}
        },
        state
      )
    end

    test "successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:connectionstate_resp)::8,
                     @total_length_connectionstate_resp::16,
                     # Connection Header ---------------
                     0::8,
                     connectionstate_response_status_code(:no_error)::8
                   >>}},
                 {:timer, :restart, {:ip_connection, 0}}
               ]
             } =
               receive_connectionstate_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 0
               )
    end

    test "error: connection_id" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:connectionstate_resp)::8,
                     @total_length_connectionstate_resp::16,
                     # Connection Header ---------------
                     27::8,
                     connectionstate_response_status_code(:connection_id)::8
                   >>}}
               ]
             } =
               receive_connectionstate_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 27
               )
    end
  end

  # ---------------
  describe "disconnect request" do
    @total_length_disconnect_resp Ip.get_structure_length([
                                    :header,
                                    :connection_header_core
                                  ])

    def receive_disconnect_req(%S{} = state, connection_id: connection_id) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_control_endpoint,
           <<
             # Header ---------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:core)::8,
             service_type_id(:disconnect_req)::8,
             Ip.get_structure_length([
               :header,
               :connection_header_core,
               :hpai
             ])::16,
             # Connection Header ---------------
             connection_id::8,
             knxnetip_constant(:reserved)::8,
             # HPAI ---------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip_num::32,
             @ets_port_control::16
           >>}
        },
        state
      )
    end

    test "successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:core)::8,
                     service_type_id(:disconnect_resp)::8,
                     @total_length_disconnect_resp::16,
                     # Connection Header ---------------
                     0::8,
                     common_error_code(:no_error)::8
                   >>}},
                 {:timer, :stop, {:ip_connection, 0}}
               ]
             } =
               receive_disconnect_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 0
               )
    end

    test "error: connection does not exist" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               []
             } =
               receive_disconnect_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 1
               )
    end
  end

  # ---------------
  test("no matching handler") do
    assert {
             %S{},
             []
           } =
             Ip.handle(
               {:knip, :from_ip,
                {@ets_control_endpoint,
                 <<
                   # Header ---------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   11::8,
                   structure_length(:header)::16
                 >>}},
               %S{}
             )
  end
end
