defmodule Knx.KnxnetIp.TunnellingTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState
  alias Knx.Frame, as: F
  alias Knx.DataCemiFrame
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.Queue

  require Knx.Defs
  import Knx.Defs

  @ets_ip Helper.convert_ip_to_number({192, 168, 178, 21})
  @ets_port_tunnelling_data 52252
  @ets_port_control 52250

  @ets_control_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_control
  }

  @ets_tunnelling_data_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_tunnelling_data
  }

  @device_object Helper.get_device_props(1)
  @knxnet_ip_parameter_object Helper.get_knxnetip_parameter_props()

  @knx_indv_addr 0x11FF
  @knx_device_indv_addr 0x2102

  @list_1_255 Enum.to_list(1..255)

  @con_tunnel %C{
    id: 0,
    con_type: :device_mgmt_con,
    dest_control_endpoint: @ets_control_endpoint,
    dest_data_endpoint: @ets_tunnelling_data_endpoint,
    con_knx_indv_addr: @knx_indv_addr,
    client_seq_counter: 0,
    server_seq_counter: 0
  }

  @con_tab_0 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{@knx_indv_addr => 0},
    :tunnel_cons_left => 0,
    0 => @con_tunnel
  }

  @con_tab_0_client_seq_1 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{@knx_indv_addr => 0},
    :tunnel_cons_left => 0,
    0 => %{@con_tunnel | client_seq_counter: 1}
  }

  @con_tab_0_client_server_seq_1 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{@knx_indv_addr => 0},
    :tunnel_cons_left => 0,
    0 => %{@con_tunnel | client_seq_counter: 1, server_seq_counter: 1}
  }

  setup do
    Cache.start_link(%{
      objects: [device: @device_object, knxnet_ip_parameter: @knxnet_ip_parameter_object]
    })

    Queue.start_link(name: :tunnelling_queue, max_queue_size: 30)

    :timer.sleep(5)
    :ok
  end

  # ---------------
  describe "tunnelling request" do
    @knx_frame_tunnelling_req_l_data %F{
      data: <<0x47D5_000B_1001::8*6>>,
      prio: 0,
      src: nil,
      dest: nil,
      addr_t: 0,
      hops: 7,
      confirm: 0
    }

    @knx_frame_tunnelling_req_l_data_req DataCemiFrame.encode(
                                           :req,
                                           %{
                                             @knx_frame_tunnelling_req_l_data
                                             | src: 0,
                                               dest: @knx_device_indv_addr
                                           }
                                         )
    @knx_frame_tunnelling_req_l_data_con DataCemiFrame.encode(
                                           :conf,
                                           %{
                                             @knx_frame_tunnelling_req_l_data
                                             | src: @knx_indv_addr,
                                               dest: @knx_device_indv_addr
                                           }
                                         )

    @total_length_tunnelling_ack Ip.get_structure_length([
                                   :header,
                                   :connection_header_tunnelling
                                 ])
    @total_length_tunnelling_req_l_data_con Ip.get_structure_length([
                                              :header,
                                              :connection_header_tunnelling
                                            ]) + 15

    def receive_tunnelling_req(%S{} = state,
          connection_id: connection_id,
          seq_counter: seq_counter
        ) do
      Ip.handle(
        {:knip, :from_ip,
         {
           @ets_tunnelling_data_endpoint,
           <<
             # Header ---------------
             structure_length(:header)::8,
             protocol_version(:knxnetip)::8,
             service_family_id(:tunnelling)::8,
             service_type_id(:tunnelling_req)::8,
             Ip.get_structure_length([:header, :connection_header_tunnelling]) + 15::16,
             # Connection header ---------------
             structure_length(:connection_header_tunnelling),
             connection_id::8,
             seq_counter::8,
             knxnetip_constant(:reserved)::8
           >> <>
             @knx_frame_tunnelling_req_l_data_req
         }},
        state
      )
    end

    test("l_data.req, expected seq counter") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1, tunnelling_state: :waiting}
              },
              [
                {:ip, :transmit,
                 {@ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_family_id(:tunnelling)::8,
                    service_type_id(:tunnelling_ack)::8,
                    @total_length_tunnelling_ack::16,
                    # Connection header ---------------
                    structure_length(:connection_header_tunnelling)::8,
                    0::8,
                    0::8,
                    common_error_code(:no_error)::8
                  >>}},
                {:driver, :transmit, @knx_frame_tunnelling_req_l_data_req},
                {:timer, :restart, {:ip_connection, 0}}
              ]} =
               receive_tunnelling_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0, tunnelling_state: :idle}},
                 connection_id: 0,
                 seq_counter: 0
               )

      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0_client_seq_1,
                  tunnelling_state: :idle
                }
              },
              [
                {:ip, :transmit,
                 {@ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_family_id(:tunnelling)::8,
                    service_type_id(:tunnelling_req)::8,
                    @total_length_tunnelling_req_l_data_con::16,
                    # Connection header ---------------
                    structure_length(:connection_header_tunnelling),
                    0::8,
                    0::8,
                    knxnetip_constant(:reserved)::8
                  >> <> @knx_frame_tunnelling_req_l_data_con}},
                {:timer, :start, {:tunneling_req, 0}}
              ]} =
               Ip.handle(
                 {:knip, :from_knx, @knx_frame_tunnelling_req_l_data_con},
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0_client_seq_1,
                     tunnelling_state: :waiting
                   }
                 }
               )
    end

    test("l_data.req, error: expected seq counter - 1") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, tunnelling_state: :idle}
              },
              [
                {:ip, :transmit,
                 {@ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_family_id(:tunnelling)::8,
                    service_type_id(:tunnelling_ack)::8,
                    @total_length_tunnelling_ack::16,
                    # Connection header ---------------
                    structure_length(:connection_header_tunnelling)::8,
                    0::8,
                    255::8,
                    common_error_code(:no_error)::8
                  >>}}
              ]} =
               receive_tunnelling_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0, tunnelling_state: :idle}},
                 connection_id: 0,
                 seq_counter: 255
               )
    end

    test("l_data.req, error: wrong seq counter") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, tunnelling_state: :idle}
              },
              []} =
               receive_tunnelling_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0, tunnelling_state: :idle}},
                 connection_id: 0,
                 seq_counter: 22
               )
    end

    test("l_data.req, error: connection id does not exist") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, tunnelling_state: :idle}
              },
              []} =
               receive_tunnelling_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0, tunnelling_state: :idle}},
                 connection_id: 244,
                 seq_counter: 0
               )
    end
  end

  # ---------------
  describe "tunnelling ack" do
    def receive_tunnelling_ack(%S{} = state,
          connection_id: connection_id,
          seq_counter: seq_counter
        ) do
      Ip.handle(
        {:knip, :from_ip,
         {@ets_tunnelling_data_endpoint,
          <<
            # Header ---------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:tunnelling)::8,
            service_type_id(:tunnelling_ack)::8,
            Ip.get_structure_length([:header, :connection_header_tunnelling])::16,
            # Connection header ---------------
            structure_length(:connection_header_tunnelling)::8,
            connection_id::8,
            seq_counter::8,
            common_error_code(:no_error)::8
          >>}},
        state
      )
    end

    test("successful") do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0_client_server_seq_1,
                  tunnelling_state: :idle
                }
              },
              [
                {:timer, :restart, {:ip_connection, 0}},
                {:timer, :stop, {:tunnelling_req, 0}}
              ]} =
               receive_tunnelling_ack(
                 %S{
                   knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1, tunnelling_state: :idle}
                 },
                 connection_id: 0,
                 seq_counter: 0
               )
    end

    test("error: wrong seq counter") do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0_client_seq_1,
                  tunnelling_state: :idle
                }
              },
              []} =
               receive_tunnelling_ack(
                 %S{
                   knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1, tunnelling_state: :idle}
                 },
                 connection_id: 0,
                 seq_counter: 23
               )
    end

    test("error: connection id does not exist") do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0_client_seq_1,
                  tunnelling_state: :idle
                }
              },
              []} =
               receive_tunnelling_ack(
                 %S{
                   knxnetip: %IpState{con_tab: @con_tab_0_client_seq_1, tunnelling_state: :idle}
                 },
                 connection_id: 3,
                 seq_counter: 0
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
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ---------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:tunnelling)::8,
                   5::8,
                   structure_length(:header)::16
                 >>}},
               %S{}
             )
  end
end
