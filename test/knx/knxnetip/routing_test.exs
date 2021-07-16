defmodule Knx.KnxnetIp.RoutingTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.LeakyBucket

  require Knx.Defs
  import Knx.Defs

  @multicast_ip Helper.convert_ip_to_number({224, 0, 23, 12})
  @multicast_port 3671

  @ets_ip Helper.convert_ip_to_number({192, 168, 178, 21})
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
  @knxnet_ip_parameter_object Helper.get_knxnetip_parameter_props()

  setup do
    Cache.start_link(%{
      objects: [device: @device_object, knxnet_ip_parameter: @knxnet_ip_parameter_object]
    })

    :timer.sleep(5)
    :ok
  end

  # ----------------------------------------------------------------------------
  describe "routing ind" do
    @total_length_routing_lost_message Ip.get_structure_length([
                                         :header,
                                         :lost_message_info
                                       ])
    @total_length_routing_busy Ip.get_structure_length([
                                 :header,
                                 :busy_info
                               ])

    def receive_routing_ind() do
      Ip.handle(
        {:knip, :from_ip,
         {@router_endpoint,
          <<
            # Header -----------------------------------------------------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:routing)::8,
            service_type_id(:routing_ind)::8,
            structure_length(:header) + 14::16,
            # TODO is this a use case?
            # cEMI -------------------------------------------------------------
            cemi_message_code(:l_data_req)::8,
            0::8,
            1::1,
            0::1,
            1::1,
            1::1,
            0::2,
            0::1,
            0::1,
            0::1,
            7::3,
            0::4,
            0x0000::16,
            0x2102::16,
            0x05::8,
            0x47D5_000B_1001::48
          >>}},
        %S{}
      )
    end

    test("successful") do
      LeakyBucket.start_link(%{
        name: :knx_queue,
        queue_size: 0,
        max_queue_size: 100,
        queue_poll_rate: 100
      })

      assert [] = receive_routing_ind()
    end

    test("queue_overflow") do
      LeakyBucket.start_link(%{
        name: :knx_queue,
        queue_size: 100,
        max_queue_size: 100,
        queue_poll_rate: 100
      })

      assert [
               {:ethernet, :transmit,
                {@multicast_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:routing)::8,
                   service_type_id(:routing_lost_message)::8,
                   @total_length_routing_lost_message::16,
                   # Lost Message Info -----------------------------------------
                   structure_length(:lost_message_info)::8,
                   0::8,
                   1::16
                 >>}}
             ] = receive_routing_ind()
    end

    test("trigger routing_busy, target: indv addr") do
      LeakyBucket.start_link(%{
        name: :knx_queue,
        queue_size: 4,
        max_queue_size: 100,
        queue_poll_rate: 100
      })

      assert [
               {:ethernet, :transmit,
                {@router_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:routing)::8,
                   service_type_id(:routing_busy)::8,
                   @total_length_routing_busy::16,
                   # Busy Info -------------------------------------------------
                   structure_length(:busy_info)::8,
                   0::8,
                   100::16,
                   0x0000::16
                 >>}}
             ] = receive_routing_ind()
    end

    test("trigger routing_busy, target: multicast") do
      LeakyBucket.start_link(%{
        name: :knx_queue,
        queue_size: 9,
        max_queue_size: 100,
        queue_poll_rate: 100
      })

      assert [
               {:ethernet, :transmit,
                {@multicast_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:routing)::8,
                   service_type_id(:routing_busy)::8,
                   @total_length_routing_busy::16,
                   # Busy Info -------------------------------------------------
                   structure_length(:busy_info)::8,
                   0::8,
                   100::16,
                   0x0000::16
                 >>}}
             ] = receive_routing_ind()
    end
  end

  # ----------------------------------------------------------------------------
  describe "routing busy" do
    def receive_routing_busy(device_state, routing_busy_control_field) do
      Ip.handle(
        {:knip, :from_ip,
         {@router_endpoint,
          <<
            # Header ------------------------------------------------------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:routing)::8,
            service_type_id(:routing_busy)::8,
            Ip.get_structure_length([:header, :busy_info])::16,
            # Busy Info ---------------------------------------------------------
            structure_length(:busy_info)::8,
            device_state::8,
            100::16,
            routing_busy_control_field::16
          >>}},
        %S{}
      )
    end

    test("successful") do
      assert [] = receive_routing_busy(0, 0)
    end
  end

  # ---------------------------------------------------------------------------
  describe "routing lost message" do
    def receive_routing_lost_message() do
      Ip.handle(
        {:knip, :from_ip,
         {@multicast_endpoint,
          <<
            # Header ------------------------------------------------------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:routing)::8,
            service_type_id(:routing_lost_message)::8,
            Ip.get_structure_length([:header, :lost_message_info])::16,
            # Lost Message Info -------------------------------------------------
            structure_length(:lost_message_info)::8,
            0::8,
            0::16
          >>}},
        %S{}
      )
    end

    test("successful") do
      assert [] = receive_routing_lost_message()
    end
  end

  # ----------------------------------------------------------------------------

  test("no matching handler") do
    assert [] =
             Ip.handle(
               {:knip, :from_ip,
                {@multicast_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:routing)::8,
                   5::8,
                   structure_length(:header)::16,
                 >>}},
               %S{}
             )
  end
end
