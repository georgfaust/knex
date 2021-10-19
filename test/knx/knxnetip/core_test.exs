defmodule Knx.KnxnetIp.CoreTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: KnipState
  alias Knx.KnxnetIp.Knip
  alias Knx.KnxnetIp.Core
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.Parameter, as: KnipParameter

  require Knx.Defs
  import Knx.Defs

  @ets_ip {192, 168, 178, 21}
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
  @knxnet_ip_parameter_object KnipParameter.get_knxnetip_parameter_props()

  @knx_indv_addr Application.get_env(:knx, :knx_indv_addr, 0x1101)

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
    @search_req Telegram.search_req()
    @search_resp_interface Telegram.search_resp(:knx_ip_interface)
    @search_resp Telegram.search_resp(:knx_ip)

    test "successful, knx_ip_interface" do
      Application.put_env(:knx, :knx_device_type, :knx_ip_interface)

      assert {
               %S{},
               [{:ip, :transmit, {@ets_discovery_endpoint, @search_resp_interface}}]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_discovery_endpoint, @search_req}},
                 %S{}
               )
    end

    test "successful, knx_ip" do
      Application.put_env(:knx, :knx_device_type, :knx_ip)

      assert {
               %S{},
               [{:ip, :transmit, {@ets_discovery_endpoint, @search_resp}}]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_discovery_endpoint, @search_req}},
                 %S{}
               )
    end
  end

  # ---------------
  describe "description request" do
    @description_req Telegram.description_req()
    @description_resp_interface Telegram.description_resp(:knx_ip_interface)
    @description_resp Telegram.description_resp(:knx_ip)

    test "successful, knx_ip_interface" do
      Application.put_env(:knx, :knx_device_type, :knx_ip_interface)

      assert {
               %S{},
               [{:ip, :transmit, {@ets_control_endpoint, @description_resp_interface}}]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_control_endpoint, @description_req}},
                 %S{}
               )
    end

    test "successful, knx_ip" do
      Application.put_env(:knx, :knx_device_type, :knx_ip)

      assert {
               %S{},
               [{:ip, :transmit, {@ets_control_endpoint, @description_resp}}]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_control_endpoint, @description_req}},
                 %S{}
               )
    end
  end

  # ---------------
  describe "connect request" do
    @connect_req_device_management Telegram.connect_req(:device_management)

    @connect_req_tunnelling_tunnel_con_linklayer Telegram.connect_req(
                                                   :tunnelling,
                                                   con_type: :tunnel_con,
                                                   tunnelling_knx_layer: :tunnel_linklayer
                                                 )

    @connect_req_tunnelling_tunnel_con_raw Telegram.connect_req(
                                             :tunnelling,
                                             con_type: :tunnel_con,
                                             tunnelling_knx_layer: :tunnel_raw
                                           )

    @connect_req_tunnelling_remlog_con_linklayer Telegram.connect_req(
                                                   :tunnelling,
                                                   con_type: :remlog_con,
                                                   tunnelling_knx_layer: :tunnel_linklayer
                                                 )

    @connect_resp_device_management_no_error_channel_0 Telegram.connect_resp(
                                                         :no_error,
                                                         :device_management,
                                                         0
                                                       )

    @connect_resp_device_management_error_no_more_cons Telegram.connect_resp(
                                                         :error,
                                                         :no_more_connections
                                                       )

    @connect_resp_tunnelling_no_error_channel_1 Telegram.connect_resp(
                                                  :no_error,
                                                  :tunnelling,
                                                  1
                                                )

    @connect_resp_tunnelling_error_no_more_cons Telegram.connect_resp(
                                                  :error,
                                                  :no_more_connections
                                                )

    @connect_resp_tunnelling_error_con_option Telegram.connect_resp(
                                                :error,
                                                :connection_option
                                              )

    @connect_resp_tunnelling_error_con_type Telegram.connect_resp(
                                              :error,
                                              :connection_type
                                            )

    test "device management, successful" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint, @connect_resp_device_management_no_error_channel_0}},
                 {:timer, :start, {:ip_connection, 0}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_control_endpoint, @connect_req_device_management}},
                 %S{knxnetip: %KnipState{con_tab: %{}}}
               )
    end

    test "device management, error: no_more_connections" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_full}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint, @connect_resp_device_management_error_no_more_cons}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_control_endpoint, @connect_req_device_management}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_full}}
               )
    end

    test "tunnelling, successful" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_1}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint, @connect_resp_tunnelling_no_error_channel_1}},
                 {:timer, :start, {:ip_connection, 1}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip,
                  {@ets_control_endpoint, @connect_req_tunnelling_tunnel_con_linklayer}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_0}}
               )
    end

    test "tunnelling, error: no_more_connections" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_1}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint, @connect_resp_tunnelling_error_no_more_cons}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip,
                  {@ets_control_endpoint, @connect_req_tunnelling_tunnel_con_linklayer}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_1}}
               )
    end

    test "tunnelling, error: connection_option" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint, @connect_resp_tunnelling_error_con_option}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip,
                  {@ets_control_endpoint, @connect_req_tunnelling_tunnel_con_raw}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_0}}
               )
    end

    test "error: connection_type" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint, @connect_resp_tunnelling_error_con_type}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip,
                  {@ets_control_endpoint, @connect_req_tunnelling_remlog_con_linklayer}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_0}}
               )
    end
  end

  # ---------------
  describe "connectionstate request" do
    @connectionstate_req_channel_0 Telegram.connectionstate_req(0)
    @connectionstate_req_channel_27 Telegram.connectionstate_req(27)

    @connectionstate_resp_channel_0_no_error Telegram.connectionstate_resp(0, :no_error)
    @connectionstate_resp_channel_27_error_con_id Telegram.connectionstate_resp(
                                                    27,
                                                    :connection_id
                                                  )

    test "successful" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint, @connectionstate_resp_channel_0_no_error}},
                 {:timer, :restart, {:ip_connection, 0}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_control_endpoint, @connectionstate_req_channel_0}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_0}}
               )
    end

    test "error: connection_id" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_0}},
               [
                 {:ip, :transmit,
                  {@ets_control_endpoint, @connectionstate_resp_channel_27_error_con_id}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_control_endpoint, @connectionstate_req_channel_27}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_0}}
               )
    end
  end

  # ---------------
  describe "disconnect request" do
    @disconnect_req_channel_0 Telegram.disconnect_req(0)
    @disconnect_req_channel_1 Telegram.disconnect_req(1)

    @disconnect_resp_channel_0 Telegram.disconnect_resp(0)

    test "successful" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab}},
               [
                 {:ip, :transmit, {@ets_control_endpoint, @disconnect_resp_channel_0}},
                 {:timer, :stop, {:ip_connection, 0}}
               ]
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_control_endpoint, @disconnect_req_channel_0}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_0}}
               )
    end

    test "error: connection does not exist" do
      assert {
               %S{knxnetip: %KnipState{con_tab: @con_tab_0}},
               []
             } =
               Knip.handle(
                 {:knip, :from_ip, {@ets_control_endpoint, @disconnect_req_channel_1}},
                 %S{knxnetip: %KnipState{con_tab: @con_tab_0}}
               )
    end
  end

  # ---------------
  describe "disconnect request creation" do
    @disconnect_req_channel_0 Telegram.disconnect_req(0, {0, 0, 0, 0}, 3671)

    test "successful" do
      assert {:ip, :transmit, {_ep, @disconnect_req_channel_0}} =
               Core.disconnect_req(0, @con_tab_0)
    end
  end

  # ---------------
  test("no matching handler") do
    assert {
             %S{},
             []
           } =
             Knip.handle(
               {:knip, :from_ip,
                {@ets_control_endpoint,
                 <<
                   # Header ---------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:core)::8,
                   11::8,
                   structure_length(:header) + 1::16,
                   0::8
                 >>}},
               %S{}
             )
  end

  test("invalid service familiy") do
    assert {
             %S{},
             []
           } =
             Knip.handle(
               {:knip, :from_ip,
                {@ets_control_endpoint,
                 <<
                   # Header ---------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   0x06::8,
                   11::8,
                   structure_length(:header) + 1::16,
                   0::8
                 >>}},
               %S{}
             )
  end
end
