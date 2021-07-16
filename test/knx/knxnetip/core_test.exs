defmodule Knx.KnxnetIp.CoreTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep

  require Knx.Defs
  import Knx.Defs

  @ip_interface_ip Helper.convert_ip_to_number({192, 168, 178, 62})
  @ip_interface_port 3671

  @ets_ip Helper.convert_ip_to_number({192, 168, 178, 21})
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
  @con_255 %C{id: 255, con_type: :tunnel_con, dest_data_endpoint: @ets_tunnelling_data_endpoint}

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
    @total_length_search_resp Ip.get_structure_length([
                                :header,
                                :hpai,
                                :dib_device_info,
                                :dib_supp_svc_families
                              ])
    test "successful" do
      IO.inspect(<<
        # Header ----------------------------------------------------
        structure_length(:header)::8,
        protocol_version(:knxnetip)::8,
        service_family_id(:core)::8,
        service_type_id(:search_resp)::8,
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
      >>)

      assert [
               {:ip, :transmit,
                {@ets_discovery_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:search_resp)::8,
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
                   :knip,
                   :from_ip,
                   {@ets_discovery_endpoint,
                    <<
                      # Header --------------------------------------------------
                      structure_length(:header)::8,
                      protocol_version(:knxnetip)::8,
                      service_family_id(:core)::8,
                      service_type_id(:search_req)::8,
                      Ip.get_structure_length([:header, :hpai])::16,
                      # HPAI ----------------------------------------------------
                      structure_length(:hpai)::8,
                      protocol_code(:udp)::8,
                      @ets_ip::32,
                      @ets_port_discovery::16
                    >>}
                 },
                 %S{}
               )
    end
  end

  # ----------------------------------------------------------------------------
  describe "description request" do
    @total_length_description_resp Ip.get_structure_length([
                                     :header,
                                     :dib_device_info,
                                     :dib_supp_svc_families
                                   ])

    test "successful" do
      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:description_resp)::8,
                   @total_length_description_resp::16,
                   # DIB Device Info -------------------------------------------
                   structure_length(:dib_device_info)::8,
                   description_type_code(:device_info)::8,
                   @knx_medium::8,
                   @device_status::8,
                   # wir muessen uns auf einheitliche abkuerzungen einigen (--> Gloassar)
                   # einige deiner consts koennte man evtl auch noch so abkuerzen
                   # dass es weiter gut lesbar bleibt und mehr function header in eine zeile passen
                   # zb
                   #  structure -> struct
                   #  protocol -> prot
                   #  service -> srv
                   #  ...
                   # ist zu diskutieren!
                   # es gibt auch gute gruende das nicht zu tun
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
                   :knip,
                   :from_ip,
                   {@ets_control_endpoint,
                    <<
                      # Header --------------------------------------------------
                      structure_length(:header)::8,
                      protocol_version(:knxnetip)::8,
                      service_family_id(:core)::8,
                      service_type_id(:description_req)::8,
                      Ip.get_structure_length([:header, :hpai])::16,
                      # HPAI ----------------------------------------------------
                      structure_length(:hpai)::8,
                      protocol_code(:udp)::8,
                      @ets_ip::32,
                      @ets_port_control::16
                    >>}
                 },
                 %S{}
               )
    end
  end

  # ----------------------------------------------------------------------------
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

    def receive_connect_req_device_management() do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_control_endpoint,
           <<
             # Header -----------------------------------------------------------
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
             # HPAI -------------------------------------------------------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip::32,
             @ets_port_control::16,
             # HPAI -------------------------------------------------------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip::32,
             @ets_port_device_mgmt_data::16,
             # CRI --------------------------------------------------------------
             structure_length(:crd_device_mgmt_con)::8,
             con_type_code(:device_mgmt_con)::8
           >>}
        },
        %S{}
      )
    end

    def receive_connect_req_tunnelling(
          con_type: con_type,
          tunnelling_knx_layer: tunnelling_knx_layer
        ) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_control_endpoint,
           <<
             # Header -----------------------------------------------------------
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
             # HPAI -------------------------------------------------------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip::32,
             @ets_port_control::16,
             # HPAI -------------------------------------------------------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip::32,
             @ets_port_tunnelling_data::16,
             # CRI --------------------------------------------------------------
             structure_length(:cri_tunnel_con)::8,
             con_type_code(con_type)::8,
             tunnelling_knx_layer_code(tunnelling_knx_layer)::8,
             knxnetip_constant(:reserved)::8
           >>}
        },
        %S{}
      )
    end

    test "device management, successful" do
      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:connect_resp)::8,
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
                   structure_length(:crd_device_mgmt_con)::8,
                   con_type_code(:device_mgmt_con)::8
                 >>}},
               {:timer, :start, {:ip_connection, 1}}
             ] = receive_connect_req_device_management()
    end

    test "device management, error: no_more_connections" do
      Cache.put(:con_tab, %{
        :free_mgmt_ids => []
      })

      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:connect_resp)::8,
                   @total_length_connect_resp_error::16,
                   connect_response_status_code(:no_more_connections)::8
                 >>}}
             ] = receive_connect_req_device_management()
    end

    test "tunnelling, successful" do
      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:connect_resp)::8,
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
                   structure_length(:crd_tunnel_con)::8,
                   con_type_code(:tunnel_con)::8,
                   @knx_indv_addr::16
                 >>}},
               {:timer, :start, {:ip_connection, 255}}
             ] =
               receive_connect_req_tunnelling(
                 con_type: :tunnel_con,
                 tunnelling_knx_layer: :tunnel_linklayer
               )
    end

    test "tunnelling, error: no_more_connections" do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:connect_resp)::8,
                   @total_length_connect_resp_error::16,
                   connect_response_status_code(:no_more_connections)::8
                 >>}}
             ] =
               receive_connect_req_tunnelling(
                 con_type: :tunnel_con,
                 tunnelling_knx_layer: :tunnel_linklayer
               )
    end

    test "tunnelling, error: connection_option" do
      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:connect_resp)::8,
                   @total_length_connect_resp_error::16,
                   connect_response_status_code(:connection_option)::8
                 >>}}
             ] =
               receive_connect_req_tunnelling(
                 con_type: :tunnel_con,
                 tunnelling_knx_layer: :tunnel_raw
               )
    end

    test "error: connection_type" do
      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:connect_resp)::8,
                   @total_length_connect_resp_error::16,
                   connect_response_status_code(:connection_type)::8
                 >>}}
             ] =
               receive_connect_req_tunnelling(
                 con_type: :remlog_con,
                 tunnelling_knx_layer: :tunnel_linklayer
               )
    end
  end

  # ----------------------------------------------------------------------------
  describe "connectionstate request" do
    @total_length_connectionstate_resp Ip.get_structure_length([
                                         :header,
                                         :connection_header_core
                                       ])

    def receive_connectionstate_req(connection_id: connection_id) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_control_endpoint,
           <<
             # Header -----------------------------------------------------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:core)::8,
             service_type_id(:connectionstate_req)::8,
             Ip.get_structure_length([
               :header,
               :connection_header_core,
               :hpai
             ])::16,
             # Connection Header ------------------------------------------------
             connection_id::8,
             knxnetip_constant(:reserved)::8,
             # HPAI -------------------------------------------------------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip::32,
             @ets_port_control::16
           >>}
        },
        %S{}
      )
    end

    test "successful" do
      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:connectionstate_resp)::8,
                   @total_length_connectionstate_resp::16,
                   # Connection Header -----------------------------------------
                   0::8,
                   connectionstate_response_status_code(:no_error)::8
                 >>}},
               {:timer, :restart, {:ip_connection, 0}}
             ] = receive_connectionstate_req(connection_id: 0)
    end

    test "error: connection_id" do
      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:connectionstate_resp)::8,
                   @total_length_connectionstate_resp::16,
                   # Connection Header -----------------------------------------
                   27::8,
                   connectionstate_response_status_code(:connection_id)::8
                 >>}}
             ] = receive_connectionstate_req(connection_id: 27)
    end
  end

  # ----------------------------------------------------------------------------
  describe "disconnect request" do
    @total_length_disconnect_resp Ip.get_structure_length([
                                    :header,
                                    :connection_header_core
                                  ])

    def receive_disconnect_req(connection_id: connection_id) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_control_endpoint,
           <<
             # Header -----------------------------------------------------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:core)::8,
             service_type_id(:disconnect_req)::8,
             Ip.get_structure_length([
               :header,
               :connection_header_core,
               :hpai
             ])::16,
             # Connection Header ------------------------------------------------
             connection_id::8,
             knxnetip_constant(:reserved)::8,
             # HPAI -------------------------------------------------------------
             structure_length(:hpai)::8,
             protocol_code(:udp)::8,
             @ets_ip::32,
             @ets_port_control::16
           >>}
        },
        %S{}
      )
    end

    test "successful" do
      assert [
               {:ip, :transmit,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   service_type_id(:disconnect_resp)::8,
                   @total_length_disconnect_resp::16,
                   # Connection Header -----------------------------------------
                   0::8,
                   common_error_code(:no_error)::8
                 >>}},
               {:timer, :stop, {:ip_connection, 0}}
             ] = receive_disconnect_req(connection_id: 0)
    end

    test "error: connection does not exist" do
      assert [] = receive_disconnect_req(connection_id: 1)
    end
  end

  # ----------------------------------------------------------------------------

  test("no matching handler") do
    assert [] =
             Ip.handle(
               {:knip, :from_ip,
                {@ets_control_endpoint,
                 <<
                   # Header ----------------------------------------------------
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
