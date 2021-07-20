defmodule Knx.KnxnetIp.DeviceManagementTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep

  require Knx.Defs
  import Knx.Defs

  @ets_ip Helper.convert_ip_to_number({192, 168, 178, 21})
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
  @knxnet_ip_parameter_object Helper.get_knxnetip_parameter_props()

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
    @total_length_device_config_ack Ip.get_structure_length([
                                      :header,
                                      :connection_header_device_management
                                    ])

    @total_length_device_config_req Ip.get_structure_length([
                                      :header,
                                      :connection_header_device_management
                                    ]) + 9
    @total_length_device_config_req_error_prop_read Ip.get_structure_length([
                                                      :header,
                                                      :connection_header_device_management
                                                    ]) + 8

    def receive_device_configuration_req_m_propread(
          %S{} = state,
          connection_id: connection_id,
          cemi_message_type: cemi_message_type,
          pid: pid,
          start: start,
          data: data
        ) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_device_mgmt_data_endpoint,
           <<
             # Header ---------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:device_management)::8,
             service_type_id(:device_configuration_req)::8,
             Ip.get_structure_length([
               :header,
               :connection_header_device_management
             ]) + 7::16,
             # Connection header ---------------
             structure_length(:connection_header_device_management)::8,
             connection_id::8,
             0::8,
             knxnetip_constant(:reserved)::8,
             # cEMI ---------------
             cemi_message_code(cemi_message_type)::8,
             0::16,
             1::8,
             pid::8,
             1::4,
             start::12
           >> <>
             <<data::bits>>}
        },
        state
      )
    end

    test "m_propread.req, successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:device_management)::8,
                     service_type_id(:device_configuration_ack)::8,
                     @total_length_device_config_ack::16,
                     # Connection header ---------------
                     structure_length(:connection_header_device_management)::8,
                     0::8,
                     0::8,
                     common_error_code(:no_error)::8
                   >>}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:device_management)::8,
                     service_type_id(:device_configuration_req)::8,
                     @total_length_device_config_req::16,
                     # Connection header ---------------
                     structure_length(:connection_header_device_management)::8,
                     0::8,
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # cEMI ---------------
                     cemi_message_code(:m_propread_con)::8,
                     0::16,
                     1::8,
                     0x53::8,
                     1::4,
                     1::12,
                     0x07B0::16
                   >>}},
                 {:timer, :start, {:device_management_req, 0}}
               ]
             } =
               receive_device_configuration_req_m_propread(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 0,
                 cemi_message_type: :m_propread_req,
                 pid: 0x53,
                 start: 1,
                 data: <<>>
               )
    end

    test "m_propread.req, error: property read, invalid pid" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:device_management)::8,
                     service_type_id(:device_configuration_ack)::8,
                     @total_length_device_config_ack::16,
                     # Connection header ---------------
                     structure_length(:connection_header_device_management)::8,
                     0::8,
                     0::8,
                     common_error_code(:no_error)::8
                   >>}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:device_management)::8,
                     service_type_id(:device_configuration_req)::8,
                     @total_length_device_config_req_error_prop_read::16,
                     # Connection header ---------------
                     structure_length(:connection_header_device_management)::8,
                     0::8,
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # cEMI ---------------
                     cemi_message_code(:m_propread_con)::8,
                     0::16,
                     1::8,
                     0x99::8,
                     0::4,
                     1::12,
                     cemi_error_code(:unspecific)
                   >>}},
                 {:timer, :start, {:device_management_req, 0}}
               ]
             } =
               receive_device_configuration_req_m_propread(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 0,
                 cemi_message_type: :m_propread_req,
                 pid: 0x99,
                 start: 1,
                 data: <<>>
               )
    end

    test "m_propread.req, error: property read, invalid start" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:device_management)::8,
                     service_type_id(:device_configuration_ack)::8,
                     @total_length_device_config_ack::16,
                     # Connection header ---------------
                     structure_length(:connection_header_device_management)::8,
                     0::8,
                     0::8,
                     common_error_code(:no_error)::8
                   >>}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:device_management)::8,
                     service_type_id(:device_configuration_req)::8,
                     @total_length_device_config_req_error_prop_read::16,
                     # Connection header ---------------
                     structure_length(:connection_header_device_management)::8,
                     0::8,
                     0::8,
                     knxnetip_constant(:reserved)::8,
                     # cEMI ---------------
                     cemi_message_code(:m_propread_con)::8,
                     0::16,
                     1::8,
                     0x53::8,
                     0::4,
                     100::12,
                     cemi_error_code(:unspecific)
                   >>}},
                 {:timer, :start, {:device_management_req, 0}}
               ]
             } =
               receive_device_configuration_req_m_propread(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 0,
                 cemi_message_type: :m_propread_req,
                 pid: 0x53,
                 start: 100,
                 data: <<>>
               )
    end

    test "m_propread.con, successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:ip, :transmit,
                  {@ets_device_mgmt_data_endpoint,
                   <<
                     # Header ---------------
                     structure_length(:header)::8,
                     protocol_version(:knxnetip)::8,
                     service_family_id(:device_management)::8,
                     service_type_id(:device_configuration_ack)::8,
                     @total_length_device_config_ack::16,
                     # Connection header ---------------
                     structure_length(:connection_header_device_management)::8,
                     0::8,
                     0::8,
                     common_error_code(:no_error)::8
                   >>}}
               ]
             } =
               receive_device_configuration_req_m_propread(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 0,
                 cemi_message_type: :m_propread_con,
                 pid: 0x53,
                 start: 1,
                 data: <<0>>
               )
    end

    test "error: connection does not exist" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               []
             } =
               receive_device_configuration_req_m_propread(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 87,
                 cemi_message_type: :m_propread_req,
                 pid: 0x53,
                 start: 1,
                 data: <<>>
               )
    end
  end

  # ---------------
  describe "device configuration ack" do
    @total_length_device_config_ack Ip.get_structure_length([
                                      :header,
                                      :connection_header_device_management
                                    ])

    def receive_device_configuration_ack(
          %S{} = status,
          connection_id: connection_id,
          seq_counter: seq_counter
        ) do
      Ip.handle(
        {
          :knip,
          :from_ip,
          {@ets_device_mgmt_data_endpoint,
           <<
             # Header ---------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:device_management)::8,
             service_type_id(:device_configuration_ack)::8,
             @total_length_device_config_ack::16,
             # Connection header ---------------
             structure_length(:connection_header_device_management)::8,
             connection_id::8,
             seq_counter::8,
             common_error_code(:no_error)::8
           >>}
        },
        status
      )
    end

    test "successful" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0_server_seq_1}},
               [
                 {:timer, :restart, {:ip_connection, 0}},
                 {:timer, :stop, {:device_management_req, 0}}
               ]
             } =
               receive_device_configuration_ack(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 0,
                 seq_counter: 0
               )
    end

    test "error: connection id does not exist" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               []
             } =
               receive_device_configuration_ack(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 45,
                 seq_counter: 0
               )
    end

    test "error: sequence counter wrong" do
      assert {
               %S{knxnetip: %IpState{con_tab: @con_tab_0}},
               []
             } =
               receive_device_configuration_ack(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}},
                 connection_id: 0,
                 seq_counter: 21
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
                {@ets_device_mgmt_data_endpoint,
                 <<
                   # Header ---------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:device_management)::8,
                   5::8,
                   structure_length(:header)::16
                 >>}},
               %S{}
             )
  end
end
