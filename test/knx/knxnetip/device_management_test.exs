defmodule Knx.KnxnetIp.DeviceManagementTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState
  alias Knx.KnxnetIp.Ip
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.Parameter, as: KnipParameter

  require Knx.Defs
  import Knx.Defs

  @ets_ip {192, 168, 178, 21}
  @ets_port_device_mgmt_data 52252
  @ets_port_control 52250

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

  @device_object Helper.get_device_props(1)
  @knxnet_ip_parameter_object KnipParameter.get_knxnetip_parameter_props()

  @list_1_255 Enum.to_list(1..255)

  @con_mgmt %C{
    id: 0,
    con_type: :device_mgmt_con,
    dest_control_endpoint: @ets_control_endpoint,
    dest_data_endpoint: @ets_device_mgmt_data_endpoint,
    client_seq_counter: 0,
    server_seq_counter: 0
  }

  @con_tab_0 %{
    :free_ids => @list_1_255,
    :tunnel_cons_left => 1,
    0 => @con_mgmt
  }

  @con_tab_0_client_seq_1 %{
    :free_ids => @list_1_255,
    :tunnel_cons_left => 1,
    0 => %{@con_mgmt | client_seq_counter: 1}
  }

  @con_tab_0_server_seq_1 %{
    :free_ids => @list_1_255,
    :tunnel_cons_left => 1,
    0 => %{@con_mgmt | server_seq_counter: 1}
  }

  setup do
    Cache.start_link(%{
      objects: [device: @device_object, knxnet_ip_parameter: @knxnet_ip_parameter_object]
    })

    :timer.sleep(5)
    :ok
  end

  # ---------------
  describe "device configuration request" do
    @device_configuration_req_propread_req_successful Telegram.device_configuration_req(
                                                        0,
                                                        0,
                                                        :m_propread_req,
                                                        0x53,
                                                        1,
                                                        1,
                                                        <<>>
                                                      )

    @device_configuration_req_propread_req_successful_con Telegram.device_configuration_req(
                                                            0,
                                                            0,
                                                            :m_propread_con,
                                                            0x53,
                                                            1,
                                                            1,
                                                            <<0x07B0::16>>
                                                          )

    @device_configuration_req_propread_req_invalid_pid Telegram.device_configuration_req(
                                                         0,
                                                         0,
                                                         :m_propread_req,
                                                         0x99,
                                                         1,
                                                         1,
                                                         <<>>
                                                       )

    @device_configuration_req_propread_req_invalid_pid_con Telegram.device_configuration_req(
                                                             0,
                                                             0,
                                                             :m_propread_con,
                                                             0x99,
                                                             0,
                                                             1,
                                                             <<cemi_error_code(:unspecific)>>
                                                           )

    @device_configuration_req_propread_req_invalid_start Telegram.device_configuration_req(
                                                           0,
                                                           0,
                                                           :m_propread_req,
                                                           0x53,
                                                           1,
                                                           100,
                                                           <<>>
                                                         )

    @device_configuration_req_propread_req_invalid_start_con Telegram.device_configuration_req(
                                                               0,
                                                               0,
                                                               :m_propread_con,
                                                               0x53,
                                                               0,
                                                               100,
                                                               <<cemi_error_code(:unspecific)>>
                                                             )

    @device_configuration_req_propread_req_connection_inexistent Telegram.device_configuration_req(
                                                                   87,
                                                                   0,
                                                                   :m_propread_req,
                                                                   0x53,
                                                                   1,
                                                                   1,
                                                                   <<>>
                                                                 )

    @device_configuration_req_propread_con_successful Telegram.device_configuration_req(
                                                        0,
                                                        0,
                                                        :m_propread_con,
                                                        0x53,
                                                        1,
                                                        1,
                                                        <<0>>
                                                      )

    @device_configuration_ack_channel_0_seq_0_no_error Telegram.device_configuration_ack(
                                                         0,
                                                         0,
                                                         :no_error
                                                       )

    @device_configuration_req_propwrite_req_successful Telegram.device_configuration_req(
                                                         0,
                                                         0,
                                                         :m_propwrite_req,
                                                         0x53,
                                                         1,
                                                         1,
                                                         <<0x07B0::16>>
                                                       )

    @device_configuration_req_propwrite_req_successful_con Telegram.device_configuration_req(
                                                             0,
                                                             0,
                                                             :m_propwrite_con,
                                                             0x53,
                                                             1,
                                                             1,
                                                             <<>>
                                                           )

    @device_configuration_req_propwrite_req_invalid_pid Telegram.device_configuration_req(
                                                          0,
                                                          0,
                                                          :m_propwrite_req,
                                                          0x99,
                                                          1,
                                                          1,
                                                          <<0x07B0::16>>
                                                        )

    @device_configuration_req_propwrite_req_invalid_pid_con Telegram.device_configuration_req(
                                                              0,
                                                              0,
                                                              :m_propwrite_con,
                                                              0x99,
                                                              0,
                                                              1,
                                                              <<cemi_error_code(:unspecific)>>
                                                            )

    @device_configuration_req_propread_req_wrong_seq Telegram.device_configuration_req(
                                                       0,
                                                       17,
                                                       :m_propread_req,
                                                       0x53,
                                                       1,
                                                       1,
                                                       <<>>
                                                     )

    @device_configuration_req_reset_req Telegram.device_configuration_req(0, 0, :m_reset_req)

    test "m_propread.req, successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_0_seq_0_no_error}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_req_successful_con}},
                 {:timer, :start, {:device_management_req, 0}}
               ]
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_req_successful}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "m_propread.req, error: property read, invalid pid" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_0_seq_0_no_error}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_req_invalid_pid_con}},
                 {:timer, :start, {:device_management_req, 0}}
               ]
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_req_invalid_pid}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "m_propread.req, error: property read, invalid start" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_0_seq_0_no_error}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_req_invalid_start_con}},
                 {:timer, :start, {:device_management_req, 0}}
               ]
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_req_invalid_start}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "m_propread.con, successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_0_seq_0_no_error}}
               ]
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_con_successful}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "error: connection does not exist" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               []
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_req_connection_inexistent}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "m_propwrite.req, successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_0_seq_0_no_error}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propwrite_req_successful_con}},
                 {:timer, :start, {:device_management_req, 0}}
               ]
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propwrite_req_successful}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "m_propwrite.req, error: property read, invalid pid" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_0_seq_0_no_error}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propwrite_req_invalid_pid_con}},
                 {:timer, :start, {:device_management_req, 0}}
               ]
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propwrite_req_invalid_pid}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "m_propread.req, wrong seq number" do
      assert {%S{knxnetip: %IpState{con_tab: @con_tab_0}}, []} =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_req_propread_req_wrong_seq}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "m_reset.req" do
      assert {%S{knxnetip: %IpState{con_tab: @con_tab_0}}, [{:restart, :ind, :knip}]} =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint, @device_configuration_req_reset_req}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end
  end

  # ---------------
  describe "device configuration ack" do
    @device_configuration_ack_channel_45_seq_0_no_error Telegram.device_configuration_ack(
                                                          45,
                                                          0,
                                                          :no_error
                                                        )

    @device_configuration_ack_channel_0_seq_21_no_error Telegram.device_configuration_ack(
                                                          0,
                                                          21,
                                                          :no_error
                                                        )
    test "successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_server_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:timer, :stop, {:device_management_req, 0}}
               ]
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_0_seq_0_no_error}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "error: connection id does not exist" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               []
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_45_seq_0_no_error}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test "error: sequence counter wrong" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               []
             } =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_device_mgmt_data_endpoint,
                   @device_configuration_ack_channel_0_seq_21_no_error}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end
  end

  # ---------------

  test("no matching handler") do
    assert {
             %S{knxnetip: %IpState{con_tab: @con_tab_0}},
             []
           } =
             Ip.handle(
               {:knip, :from_ip,
                {@ets_device_mgmt_data_endpoint,
                 <<
                   # Header ---------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:device_management)::8,
                   5::8,
                   structure_length(:header) + 2::16,
                   0::8,
                   0::8
                 >>}},
               %S{knxnetip: %IpState{con_tab: @con_tab_0}}
             )
  end
end
