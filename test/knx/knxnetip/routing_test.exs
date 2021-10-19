defmodule Knx.KnxnetIp.RoutingTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState
  alias Knx.KnxnetIp.Knip
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.LeakyBucket
  alias Knx.KnxnetIp.Routing
  alias Knx.KnxnetIp.Parameter, as: KnipParameter

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
  @knxnet_ip_parameter_object KnipParameter.get_knxnetip_parameter_props()

  @knx_device_indv_addr 0x2102

  setup do
    Cache.start_link(%{
      objects: [device: @device_object, knxnet_ip_parameter: @knxnet_ip_parameter_object]
    })

    :timer.sleep(5)
    :ok
  end

  # ---------------
  describe "routing ind" do
    @data <<0x47D5_000B_1001::8*6>>
    @cemi_frame_ind Telegram.data_cemi_frame(
                      :l_data_ind,
                      0,
                      0x0000,
                      @knx_device_indv_addr,
                      @data
                    )

    @routing_ind Telegram.routing_ind(@cemi_frame_ind)

    test("successful") do
      assert {%S{}, [{:dl, :up, @cemi_frame_ind}]} =
               Knip.handle(
                 {:knip, :from_ip, {@router_endpoint, @routing_ind}},
                 %S{}
               )
    end
  end

  # ---------------
  describe "routing busy" do
    @routing_busy_wait_100_control_0 Telegram.routing_busy(100, 0)

    @routing_busy_wait_10_control_0 Telegram.routing_busy(10, 0)

    def receive_routing_busy(routing_busy_wait_time, routing_busy_control_field, %S{} = state) do
      Knip.handle(
        {:knip, :from_ip,
         {@router_endpoint,
          <<
            # Header ---------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:routing)::8,
            service_type_id(:routing_busy)::8,
            structure_length(:header) + structure_length(:busy_info)::16,
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
               Knip.handle(
                 {:knip, :from_ip, {@router_endpoint, @routing_busy_wait_100_control_0}},
                 %S{knxnetip: %IpState{routing_busy_count: 0}}
               )

      # if the next routing busy arrives after 10 ms, routing busy count is incremented
      :timer.sleep(15)

      assert {%S{knxnetip: %IpState{routing_busy_count: 1}} = last_state, []} =
               Knip.handle(
                 {:knip, :from_ip, {@router_endpoint, @routing_busy_wait_100_control_0}},
                 last_state
               )

      # if the next routing busy arrives within 10 ms, routing busy count is NOT incremented
      :timer.sleep(5)

      assert {%S{knxnetip: %IpState{routing_busy_count: 1}}, []} =
               Knip.handle(
                 {:knip, :from_ip, {@router_endpoint, @routing_busy_wait_100_control_0}},
                 last_state
               )
    end

    test("routing busy count, decrementation") do
      assert {%S{knxnetip: %IpState{routing_busy_count: 2}} = last_state, []} =
               Knip.handle(
                 {:knip, :from_ip, {@router_endpoint, @routing_busy_wait_10_control_0}},
                 %S{knxnetip: %IpState{routing_busy_count: 2}}
               )

      # reset_time_routing_busy_count <= now + 10 + 50 * 2 + 2 * 100
      :timer.sleep(310 + 2 * 5)

      assert {%S{knxnetip: %IpState{routing_busy_count: 1}}, []} =
               Knip.handle(
                 {:knip, :from_ip, {@router_endpoint, @routing_busy_wait_10_control_0}},
                 last_state
               )
    end
  end

  # ---------------
  describe "routing lost message" do
    @routing_lost_message Telegram.routing_lost_message()

    test("successful") do
      assert {%S{}, []} =
               Knip.handle(
                 {:knip, :from_ip, {@router_endpoint, @routing_lost_message}},
                 %S{}
               )
    end
  end

  # ---------------
  describe "routing indication" do
    @cemi_frame_req Telegram.data_cemi_frame(
                      :l_data_req,
                      0,
                      0x0000,
                      @knx_device_indv_addr,
                      @data
                    )

    @routing_ind_header <<
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:routing)::8,
      service_type_id(:routing_ind)::8,
      structure_length(:header) + byte_size(@cemi_frame_req)::16
    >>

    test("successful") do
      assert {:ip, :transmit,
              {%Ep{
                 protocol_code: protocol_code(:udp),
                 ip_addr: {224, 0, 23, 12},
                 port: 3671
               }, @routing_ind_header <> @cemi_frame_req}} = Routing.routing_ind(@cemi_frame_req)
    end
  end

  # ---------------
  describe "Leaky Bucket" do
    test("enqueue - successful") do
      LeakyBucket.start_link(
        max_queue_size: 1000,
        queue_poll_rate: 20,
        pop_fun: fn object -> Shell.Server.dispatch(nil, object) end
      )

      assert 1 = Routing.enqueue(@cemi_frame_req)
    end

    test("enqueue - queue overflow") do
      LeakyBucket.start_link(
        max_queue_size: 1,
        queue_poll_rate: 20,
        pop_fun: fn object -> Shell.Server.dispatch(nil, object) end
      )

      assert 1 = Routing.enqueue(@cemi_frame_req)
      assert :queue_overflow = Routing.enqueue(@cemi_frame_req)
    end

    test("pop object") do
      pid = self()

      LeakyBucket.start_link(
        max_queue_size: 100,
        queue_poll_rate: 5,
        pop_fun: fn object -> send(pid, object) end
      )

      Routing.enqueue(@cemi_frame_req)
      :timer.sleep(5)

      assert :ok = receive_frame()
      :timer.sleep(5)
      assert :nothing = receive_frame()
    end

    test("successful delay") do
      pid = self()

      LeakyBucket.start_link(
        max_queue_size: 100,
        queue_poll_rate: 5,
        pop_fun: fn object -> send(pid, object) end
      )

      Routing.enqueue(@cemi_frame_req)
      LeakyBucket.delay(15)
      :timer.sleep(5)

      assert :nothing = receive_frame()
      :timer.sleep(10)
      assert :ok = receive_frame()
    end
  end

  # ---------------
  test("no matching handler") do
    assert {%S{}, []} =
             Knip.handle(
               {:knip, :from_ip,
                {@multicast_endpoint,
                 <<
                   # Header ---------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:routing)::8,
                   5::8,
                   structure_length(:header) + 1::16,
                   0::8
                 >>}},
               %S{}
             )
  end

  # ---------------

  defp receive_frame() do
    receive do
      _frame -> :ok
    after
      5 -> :nothing
    end
  end
end
