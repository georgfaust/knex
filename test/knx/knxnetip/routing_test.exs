defmodule Knx.KnxnetIp.RoutingTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Frame, as: F
  alias Knx.DataCemiFrame
  alias Knx.State.KnxnetIp, as: IpState
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.LeakyBucket
  alias Knx.KnxnetIp.Routing
  alias Knx.KnxnetIp.KnxnetIpParameter

  require Knx.Defs
  import Knx.Defs

  @multicast_ip {224, 0, 23, 12}
  @multicast_port 3671

  @ets_ip {192, 168, 178, 21}
  @ets_port_routing 52253

  @router_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @ets_ip,
    port: @ets_port_routing
  }

  @multicast_endpoint %Ep{
    protocol_code: protocol_code(:udp),
    ip_addr: @multicast_ip,
    port: @multicast_port
  }

  @device_object Helper.get_device_props(1)
  @knxnet_ip_parameter_object KnxnetIpParameter.get_knxnetip_parameter_props()

  @cemi_frame_struct %F{
    data: <<0x47D5_000B_1001::8*6>>,
    prio: 0,
    src: 0x0000,
    dest: 0x2102,
    addr_t: 0,
    hops: 7,
    confirm: 0
  }

  setup do
    Cache.start_link(%{
      objects: [device: @device_object, knxnet_ip_parameter: @knxnet_ip_parameter_object]
    })

    :timer.sleep(5)
    :ok
  end

  # ---------------
  describe "routing ind" do
    @cemi_frame_ind DataCemiFrame.encode(:ind, @cemi_frame_struct)

    def receive_routing_ind(%S{} = state) do
      Ip.handle(
        {:knip, :from_ip,
         {@router_endpoint,
          <<
            # Header ---------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:routing)::8,
            service_type_id(:routing_ind)::8,
            structure_length(:header) + byte_size(@cemi_frame_ind)::16
          >> <>
            @cemi_frame_ind}},
        state
      )
    end

    test("successful") do
      assert {%S{}, [{:dl, :up, @cemi_frame_ind}]} = receive_routing_ind(%S{})
    end
  end

  # ---------------
  describe "routing busy" do
    def receive_routing_busy(routing_busy_wait_time, routing_busy_control_field, %S{} = state) do
      Ip.handle(
        {:knip, :from_ip,
         {@router_endpoint,
          <<
            # Header ---------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:routing)::8,
            service_type_id(:routing_busy)::8,
            Ip.get_structure_length([:header, :busy_info])::16,
            # Busy Info ---------------
            structure_length(:busy_info)::8,
            0::8,
            routing_busy_wait_time::16,
            routing_busy_control_field::16
          >>}},
        state
      )
    end

    test("routing busy count, incrementation") do
      assert {%S{knxnetip: %IpState{routing_busy_count: 0}} = last_state, []} =
               receive_routing_busy(100, 0, %S{knxnetip: %IpState{routing_busy_count: 0}})

      # if the next routing busy arrives after 10 ms, routing busy count is incremented
      :timer.sleep(15)

      assert {%S{knxnetip: %IpState{routing_busy_count: 1}} = last_state, []} =
               receive_routing_busy(100, 0, last_state)

      # if the next routing busy arrives within 10 ms, routing busy count is NOT incremented
      :timer.sleep(5)

      assert {%S{knxnetip: %IpState{routing_busy_count: 1}}, []} =
               receive_routing_busy(100, 0, last_state)
    end

    # TODO is there a way to test this without increasing test time by 320 ms?
    @tag :skip
    test("routing busy count, decrementation") do
      assert {%S{knxnetip: %IpState{routing_busy_count: 2}} = last_state, []} =
               receive_routing_busy(10, 0, %S{knxnetip: %IpState{routing_busy_count: 2}})

      # reset_time_routing_busy_count <= now + 10 + 50 * 2 + 2 * 100
      :timer.sleep(310 + 2 * 5)

      assert {%S{knxnetip: %IpState{routing_busy_count: 1}}, []} =
               receive_routing_busy(50, 0, last_state)
    end
  end

  # ---------------
  describe "routing lost message" do
    def receive_routing_lost_message() do
      Ip.handle(
        {:knip, :from_ip,
         {@multicast_endpoint,
          <<
            # Header ---------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:routing)::8,
            service_type_id(:routing_lost_message)::8,
            Ip.get_structure_length([:header, :lost_message_info])::16,
            # Lost Message Info ---------------
            structure_length(:lost_message_info)::8,
            0::8,
            0::16
          >>}},
        %S{}
      )
    end

    test("successful") do
      assert {%S{}, []} = receive_routing_lost_message()
    end
  end

  # ---------------
  describe "routing indication" do
    @cemi_frame_req DataCemiFrame.encode(:req, @cemi_frame_struct)

    @routing_ind_header Ip.header(
                          service_type_id(:routing_ind),
                          structure_length(:header) + byte_size(@cemi_frame_req)
                        )

    test("successful") do
      assert {:ip, :transmit,
              {%Ep{
                 protocol_code: protocol_code(:udp),
                 ip_addr: {224, 0, 23, 12},
                 port: 3671
               },
               @routing_ind_header <> @cemi_frame_req}} = Routing.routing_ind(@cemi_frame_req)
    end
  end

  # ---------------
  describe "enqueue" do
    test("successful") do
      LeakyBucket.start_link(
        max_queue_size: 1000,
        queue_poll_rate: 20,
        pop_fun: fn object -> Shell.Server.dispatch(nil, object) end
      )

      assert 1 = Routing.enqueue(@cemi_frame_req)
    end

    test("queue overflow") do
      LeakyBucket.start_link(
        max_queue_size: 1,
        queue_poll_rate: 20,
        pop_fun: fn object -> Shell.Server.dispatch(nil, object) end
      )

      assert 1 = Routing.enqueue(@cemi_frame_req)
      assert :queue_overflow = Routing.enqueue(@cemi_frame_req)
    end
  end

  # ---------------
  test("no matching handler") do
    assert {%S{}, []} =
             Ip.handle(
               {:knip, :from_ip,
                {@multicast_endpoint,
                 <<
                   # Header ---------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:routing)::8,
                   5::8,
                   structure_length(:header)::16
                 >>}},
               %S{}
             )
  end
end
