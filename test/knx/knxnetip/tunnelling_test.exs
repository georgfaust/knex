defmodule Knx.KnxnetIp.TunnellingTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState
  alias Knx.Frame, as: F
  alias Knx.DataCemiFrame
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.KnxnetIpParameter

  require Knx.Defs
  import Knx.Defs

  @ets_ip {192, 168, 178, 21}
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
  @knxnet_ip_parameter_object KnxnetIpParameter.get_knxnetip_parameter_props()

  @knx_indv_addr Application.get_env(:knx, :knx_indv_addr, 0x1101)
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

    :timer.sleep(5)
    :ok
  end

  # ---------------
  describe "tunnelling request" do
    @cemi_frame_struct %F{
      data: <<0x47D5_000B_1001::8*6>>,
      prio: 0,
      src: nil,
      dest: nil,
      addr_t: 0,
      hops: 7,
      confirm: 0
    }

    @cemi_frame_req DataCemiFrame.encode(
                      :req,
                      %{
                        @cemi_frame_struct
                        | src: @knx_indv_addr,
                          dest: @knx_device_indv_addr
                      }
                    )

    @cemi_frame_ind DataCemiFrame.encode(
                      :ind,
                      %{
                        @cemi_frame_struct
                        | src: @knx_indv_addr,
                          dest: @knx_device_indv_addr
                      }
                    )

    @cemi_frame_pos_con DataCemiFrame.encode(
                          :conf,
                          %{
                            @cemi_frame_struct
                            | src: @knx_indv_addr,
                              dest: @knx_device_indv_addr,
                              confirm: 0
                          }
                        )

    @cemi_frame_neg_con DataCemiFrame.encode(
                          :conf,
                          %{
                            @cemi_frame_struct
                            | src: @knx_indv_addr,
                              dest: @knx_device_indv_addr,
                              confirm: 1
                          }
                        )

    @total_length_tunnelling_ack Ip.get_structure_length([
                                   :header,
                                   :connection_header_tunnelling
                                 ])
    @total_length_tunnelling_req Ip.get_structure_length([
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
             structure_length(:connection_header_tunnelling)::8,
             connection_id::8,
             seq_counter::8,
             knxnetip_constant(:reserved)::8
           >> <>
             @cemi_frame_req
         }},
        state
      )
    end

    test("l_data.req, expected seq counter") do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0_client_seq_1,
                  last_data_cemi_frame: @cemi_frame_req
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
                    service_type_id(:tunnelling_ack)::8,
                    @total_length_tunnelling_ack::16,
                    # Connection header ---------------
                    structure_length(:connection_header_tunnelling)::8,
                    0::8,
                    0::8,
                    common_error_code(:no_error)::8
                  >>}},
                {:driver, :transmit, @cemi_frame_req},
                {:timer, :restart, {:ip_connection, 0}}
              ]} =
               receive_tunnelling_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}},
                 connection_id: 0,
                 seq_counter: 0
               )
    end

    test("l_data.req, error: expected seq counter - 1") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}
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
                 %S{knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}},
                 connection_id: 0,
                 seq_counter: 255
               )
    end

    test("l_data.req, error: wrong seq counter") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}
              },
              []} =
               receive_tunnelling_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}},
                 connection_id: 0,
                 seq_counter: 22
               )
    end

    test("l_data.req, error: connection id does not exist") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}
              },
              []} =
               receive_tunnelling_req(
                 %S{knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}},
                 connection_id: 244,
                 seq_counter: 0
               )
    end
  end

  # ---------------
  describe "handle up frame" do
    @tunnelling_req_l_data_req Ip.header(
                                 service_type_id(:tunnelling_req),
                                 structure_length(:header) +
                                   byte_size(@cemi_frame_req)
                               ) <> @cemi_frame_req

    @tunnelling_queue :queue.new()

    test "positive confirmation, empty queue" do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0,
                  last_data_cemi_frame: :none
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
                    @total_length_tunnelling_req::16,
                    # Connection header ---------------
                    structure_length(:connection_header_tunnelling),
                    0::8,
                    0::8,
                    knxnetip_constant(:reserved)::8
                  >> <> @cemi_frame_pos_con}},
                {:timer, :start, {:tunnelling_req, 0}}
              ]} =
               Ip.handle(
                 {:knip, :from_knx, @cemi_frame_pos_con},
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0,
                     last_data_cemi_frame: @cemi_frame_req
                   }
                 }
               )
    end

    test "positive confirmation, non-empty queue" do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0,
                  tunnelling_queue: @tunnelling_queue,
                  tunnelling_queue_size: 0,
                  last_data_cemi_frame: :none
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
                    @total_length_tunnelling_req::16,
                    # Connection header ---------------
                    structure_length(:connection_header_tunnelling),
                    0::8,
                    0::8,
                    knxnetip_constant(:reserved)::8
                  >> <> @cemi_frame_pos_con}},
                {:timer, :start, {:tunnelling_req, 0}},
                {:knip, :from_ip, {@ets_tunnelling_data_endpoint, @tunnelling_req_l_data_req}}
              ]} =
               Ip.handle(
                 {:knip, :from_knx, @cemi_frame_pos_con},
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0,
                     tunnelling_queue:
                       :queue.in(
                         {@ets_tunnelling_data_endpoint, @tunnelling_req_l_data_req},
                         @tunnelling_queue
                       ),
                     tunnelling_queue_size: 1,
                     last_data_cemi_frame: @cemi_frame_req
                   }
                 }
               )
    end

    test "negative confirmation" do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0,
                  last_data_cemi_frame: :none
                }
              },
              []} =
               Ip.handle(
                 {:knip, :from_knx, @cemi_frame_neg_con},
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0,
                     last_data_cemi_frame: @cemi_frame_req
                   }
                 }
               )
    end

    test "indication" do
      assert {%S{knxnetip: %IpState{con_tab: @con_tab_0}},
              [
                {:ip, :transmit,
                 {@ets_tunnelling_data_endpoint,
                  <<
                    # Header ---------------
                    structure_length(:header)::8,
                    protocol_version(:knxnetip)::8,
                    service_family_id(:tunnelling)::8,
                    service_type_id(:tunnelling_req)::8,
                    @total_length_tunnelling_req::16,
                    # Connection header ---------------
                    structure_length(:connection_header_tunnelling),
                    0::8,
                    0::8,
                    knxnetip_constant(:reserved)::8
                  >> <> @cemi_frame_ind}},
                {:timer, :start, {:tunnelling_req, 0}}
              ]} =
               Ip.handle(
                 {:knip, :from_knx, @cemi_frame_ind},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
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
                  last_data_cemi_frame: :none
                }
              },
              [
                {:timer, :restart, {:ip_connection, 0}},
                {:timer, :stop, {:tunnelling_req, 0}}
              ]} =
               receive_tunnelling_ack(
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0_client_seq_1,
                     last_data_cemi_frame: :none
                   }
                 },
                 connection_id: 0,
                 seq_counter: 0
               )
    end

    test("error: wrong seq counter") do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0_client_seq_1,
                  last_data_cemi_frame: :none
                }
              },
              []} =
               receive_tunnelling_ack(
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0_client_seq_1,
                     last_data_cemi_frame: :none
                   }
                 },
                 connection_id: 0,
                 seq_counter: 23
               )
    end

    test("error: connection id does not exist") do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0_client_seq_1,
                  last_data_cemi_frame: :none
                }
              },
              []} =
               receive_tunnelling_ack(
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0_client_seq_1,
                     last_data_cemi_frame: :none
                   }
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
