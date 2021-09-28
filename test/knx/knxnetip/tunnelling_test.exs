defmodule Knx.KnxnetIp.TunnellingTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState
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
    @data <<0x47D5_000B_1001::8*6>>

    @cemi_frame_req Telegram.data_cemi_frame(
                      :l_data_req,
                      0,
                      @knx_indv_addr,
                      @knx_device_indv_addr,
                      @data
                    )

    @cemi_frame_ind Telegram.data_cemi_frame(
                      :l_data_ind,
                      0,
                      @knx_indv_addr,
                      @knx_device_indv_addr,
                      @data
                    )

    @cemi_frame_pos_con Telegram.data_cemi_frame(
                          :l_data_con,
                          0,
                          @knx_indv_addr,
                          @knx_device_indv_addr,
                          @data
                        )

    @cemi_frame_neg_con Telegram.data_cemi_frame(
                          :l_data_con,
                          1,
                          @knx_indv_addr,
                          @knx_device_indv_addr,
                          @data
                        )

    @tunnelling_req_data_req_channel_0_seq_0 Telegram.tunnelling_req(
                                               0,
                                               0,
                                               @cemi_frame_req
                                             )

    @tunnelling_req_data_req_channel_0_seq_255 Telegram.tunnelling_req(
                                                 0,
                                                 255,
                                                 @cemi_frame_req
                                               )
    @tunnelling_req_data_req_channel_0_seq_22 Telegram.tunnelling_req(
                                                0,
                                                22,
                                                @cemi_frame_req
                                              )

    @tunnelling_req_data_req_channel_244_seq_0 Telegram.tunnelling_req(
                                                 244,
                                                 0,
                                                 @cemi_frame_req
                                               )

    @tunnelling_ack_channel_0_seq_0 Telegram.tunnelling_ack(0, 0)

    @tunnelling_ack_channel_0_seq_255 Telegram.tunnelling_ack(0, 255)

    test("l_data.req, expected seq counter") do
      assert {%S{
                knxnetip: %IpState{
                  con_tab: @con_tab_0_client_seq_1,
                  last_data_cemi_frame: @cemi_frame_req
                }
              },
              [
                {:ip, :transmit,
                 {@ets_tunnelling_data_endpoint, @tunnelling_ack_channel_0_seq_0}},
                {:driver, :transmit, @cemi_frame_req},
                {:timer, :restart, {:ip_connection, 0}}
              ]} =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_tunnelling_data_endpoint, @tunnelling_req_data_req_channel_0_seq_0}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test("l_data.req, error: expected seq counter - 1") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}
              },
              [
                {:ip, :transmit,
                 {@ets_tunnelling_data_endpoint, @tunnelling_ack_channel_0_seq_255}}
              ]} =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_tunnelling_data_endpoint, @tunnelling_req_data_req_channel_0_seq_255}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test("l_data.req, error: wrong seq counter") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}
              },
              []} =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_tunnelling_data_endpoint, @tunnelling_req_data_req_channel_0_seq_22}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end

    test("l_data.req, error: connection id does not exist") do
      assert {%S{
                knxnetip: %IpState{con_tab: @con_tab_0, last_data_cemi_frame: :none}
              },
              []} =
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_tunnelling_data_endpoint, @tunnelling_req_data_req_channel_244_seq_0}},
                 %S{knxnetip: %IpState{con_tab: @con_tab_0}}
               )
    end
  end

  # ---------------
  describe "handle up frame" do
    @tunnelling_req_data_pos_con_channel_0_seq_0 Telegram.tunnelling_req(
                                                   0,
                                                   0,
                                                   @cemi_frame_pos_con
                                                 )

    @tunnelling_req_data_ind_channel_0_seq_0 Telegram.tunnelling_req(
                                               0,
                                               0,
                                               @cemi_frame_ind
                                             )

    @tunnelling_req_l_data_req <<
                                 structure_length(:header)::8,
                                 protocol_version(:knxnetip)::8,
                                 service_family_id(:tunnelling)::8,
                                 service_type_id(:tunnelling_req)::8,
                                 structure_length(:header) + byte_size(@cemi_frame_req)::16
                               >> <> @cemi_frame_req

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
                 {@ets_tunnelling_data_endpoint, @tunnelling_req_data_pos_con_channel_0_seq_0}},
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
                 {@ets_tunnelling_data_endpoint, @tunnelling_req_data_pos_con_channel_0_seq_0}},
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
                 {@ets_tunnelling_data_endpoint, @tunnelling_req_data_ind_channel_0_seq_0}},
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
    @tunnelling_ack_channel_0_seq_23 Telegram.tunnelling_ack(0, 23)

    @tunnelling_ack_channel_3_seq_0 Telegram.tunnelling_ack(3, 0)

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
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_tunnelling_data_endpoint, @tunnelling_ack_channel_0_seq_0}},
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0_client_seq_1,
                     last_data_cemi_frame: :none
                   }
                 }
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
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_tunnelling_data_endpoint, @tunnelling_ack_channel_0_seq_23}},
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0_client_seq_1,
                     last_data_cemi_frame: :none
                   }
                 }
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
               Ip.handle(
                 {:knip, :from_ip,
                  {@ets_tunnelling_data_endpoint, @tunnelling_ack_channel_3_seq_0}},
                 %S{
                   knxnetip: %IpState{
                     con_tab: @con_tab_0_client_seq_1,
                     last_data_cemi_frame: :none
                   }
                 }
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
