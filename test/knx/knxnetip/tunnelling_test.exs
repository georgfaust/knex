defmodule Knx.KnxnetIp.TunnellingTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Frame, as: F
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.LeakyBucket

  require Knx.Defs
  import Knx.Defs

  @ets_ip Helper.convert_ip_to_number({192, 168, 178, 21})
  @ets_port_device_mgmt_data 52252
  @ets_port_tunnelling_data 52252

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

  @knx_indv_addr 0x11FF

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
  describe "tunnelling request" do
    @knx_frame_tunnelling_req_l_data_req %F{
      data: <<0x47D5_000B_1001::8*6>>,
      prio: 0,
      src: @knx_indv_addr,
      dest: 0x2102,
      addr_t: 0,
      hops: 7
    }
    @total_length_tunnelling_ack Ip.get_structure_length([
                                   :header,
                                   :connection_header_tunnelling
                                 ])
    @total_length_tunnelling_req_l_data_con Ip.get_structure_length([
                                              :header,
                                              :connection_header_tunnelling
                                            ]) + 15

    def receive_tunnelling_req(connection_id: connection_id, seq_counter: seq_counter) do
      Ip.handle(
        {:knip, :from_ip,
         {@ets_tunnelling_data_endpoint,
          <<
            # Header ------------------------------------------------------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:tunnelling)::8,
            service_type_id(:tunnelling_req)::8,
            Ip.get_structure_length([:header, :connection_header_tunnelling]) + 15::16,
            # Connection header -------------------------------------------------
            structure_length(:connection_header_tunnelling),
            connection_id::8,
            seq_counter::8,
            knxnetip_constant(:reserved)::8,
            # cEMI --------------------------------------------------------------
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

    test("l_data.req, expected seq counter") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:ethernet, :transmit,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:tunnelling)::8,
                   service_type_id(:tunnelling_ack)::8,
                   @total_length_tunnelling_ack::16,
                   # Connection header -----------------------------------------
                   structure_length(:connection_header_tunnelling)::8,
                   255::8,
                   0::8,
                   common_error_code(:no_error)::8
                 >>}},
               {:dl, :req, @knx_frame_tunnelling_req_l_data_req},
               {:ethernet, :transmit,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:tunnelling)::8,
                   service_type_id(:tunnelling_req)::8,
                   @total_length_tunnelling_req_l_data_con::16,
                   # Connection header -----------------------------------------
                   structure_length(:connection_header_tunnelling),
                   255::8,
                   0::8,
                   knxnetip_constant(:reserved)::8,
                   # cEMI ------------------------------------------------------
                   cemi_message_code(:l_data_con)::8,
                   0::8,
                   1::1,
                   0::1,
                   0::1,
                   0::1,
                   0::2,
                   0::1,
                   0::1,
                   0::1,
                   7::3,
                   0::4,
                   @knx_indv_addr::16,
                   0x2102::16,
                   0x05::8,
                   0x47D5_000B_1001::48
                 >>}},
               {:timer, :restart, {:ip_connection, 255}}
             ] = receive_tunnelling_req(connection_id: 255, seq_counter: 0)

      assert 1 == ConTab.get_client_seq_counter(Cache.get(:con_tab), 0xFF)
    end

    test("l_data.req, error: expected seq counter - 1") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:ethernet, :transmit,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:tunnelling)::8,
                   service_type_id(:tunnelling_ack)::8,
                   @total_length_tunnelling_ack::16,
                   # Connection header -----------------------------------------
                   structure_length(:connection_header_tunnelling)::8,
                   255::8,
                   255::8,
                   common_error_code(:no_error)::8
                 >>}}
             ] = receive_tunnelling_req(connection_id: 255, seq_counter: 255)

      assert 0 == ConTab.get_client_seq_counter(Cache.get(:con_tab), 0xFF)
    end

    test("l_data.req, error: wrong seq counter") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [] = receive_tunnelling_req(connection_id: 254, seq_counter: 1)

      assert 0 == ConTab.get_client_seq_counter(Cache.get(:con_tab), 0xFF)
    end

    test("l_data.req, error: connection id does not exist") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [] = receive_tunnelling_req(connection_id: 254, seq_counter: 1)

      assert 0 == ConTab.get_client_seq_counter(Cache.get(:con_tab), 0xFF)
    end
  end

  # ----------------------------------------------------------------------------
  describe "tunnelling ack" do
    def receive_tunnelling_ack(connection_id: connection_id, seq_counter: seq_counter) do
      Ip.handle(
        {:knip, :from_ip,
         {@ets_tunnelling_data_endpoint,
          <<
            # Header ------------------------------------------------------------
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_family_id(:tunnelling)::8,
            service_type_id(:tunnelling_ack)::8,
            Ip.get_structure_length([:header, :connection_header_tunnelling])::16,
            # Connection header -------------------------------------------------
            structure_length(:connection_header_tunnelling)::8,
            connection_id::8,
            seq_counter::8,
            common_error_code(:no_error)::8
          >>}},
        %S{}
      )
    end

    test("successful") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:timer, :restart, {:ip_connection, 255}},
               {:timer, :stop, {:device_management_req, 0}}
             ] = receive_tunnelling_ack(connection_id: 255, seq_counter: 0)

      assert 1 == ConTab.get_server_seq_counter(Cache.get(:con_tab), 0xFF)
    end

    test("error: wrong seq counter") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [] = receive_tunnelling_ack(connection_id: 255, seq_counter: 23)

      assert 0 == ConTab.get_server_seq_counter(Cache.get(:con_tab), 0xFF)
    end

    test("error: connection id does not exist") do
      Cache.put(:con_tab, %{255 => @con_255})

      assert [] = receive_tunnelling_ack(connection_id: 25, seq_counter: 0)

      assert 0 == ConTab.get_server_seq_counter(Cache.get(:con_tab), 0xFF)
    end
  end

  # ----------------------------------------------------------------------------
  describe "knx frame" do
    @knx_frame %F{
      prio: 0,
      addr_t: 0,
      hops: 7,
      src: 0x2102,
      dest: @knx_indv_addr,
      len: 0,
      data: <<0xC6>>
    }

    @total_length_tunnelling_req_l_data_ind Ip.get_structure_length([
                                              :header,
                                              :connection_header_tunnelling
                                            ]) + 10
    test("successful") do
      LeakyBucket.start_link(%{
        name: :ip_queue,
        queue_size: 0,
        max_queue_size: 100,
        queue_poll_rate: 20
      })

      Cache.put(:con_tab, %{255 => @con_255})

      assert [
               {:ethernet, :transmit,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
                   structure_length(:header)::8,
                   protocol_version(:knxnetip)::8,
                   service_family_id(:tunnelling)::8,
                   service_type_id(:tunnelling_req)::8,
                   @total_length_tunnelling_req_l_data_ind::16,
                   # Connection header -----------------------------------------
                   structure_length(:connection_header_tunnelling)::8,
                   255::8,
                   0::8,
                   knxnetip_constant(:reserved)::8,
                   # cEMI ------------------------------------------------------
                   cemi_message_code(:l_data_ind)::8,
                   0::8,
                   1::1,
                   0::1,
                   0::1,
                   0::1,
                   0::2,
                   0::1,
                   0::1,
                   0::1,
                   7::3,
                   0::4,
                   0x2102::16,
                   @knx_indv_addr::16,
                   0x00::8,
                   0xC6::8
                 >>}},
               {:timer, :start, {:tunnelling_req, 0}}
             ] =
               Ip.handle(
                 {:knip, :from_knx, @knx_frame},
                 %S{}
               )
    end
  end

  # ----------------------------------------------------------------------------

  test("no matching handler") do
    assert [] =
             Ip.handle(
               {:knip, :from_ip,
                {@ets_tunnelling_data_endpoint,
                 <<
                   # Header ----------------------------------------------------
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
