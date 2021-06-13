defmodule Knx.KnxnetIp.ConTabTest do
  use ExUnit.Case

  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.Endpoint, as: Ep

  @control_endpoint %Ep{ip_addr: 0xC0A8_B23E, port: 0x0E75}
  @data_endpoint %Ep{ip_addr: 0xC0A8_B23E, port: 0x0E76}

  @list_0_254 Enum.to_list(0..254)
  @list_1_254 Enum.to_list(1..254)

  @con_0 %C{
    id: 0,
    con_type: :device_mgmt_con,
    dest_control_endpoint: @control_endpoint,
    dest_data_endpoint: @data_endpoint
  }

  @con_255 %C{
    id: 255,
    con_type: :tunnel_con,
    dest_control_endpoint: @control_endpoint,
    dest_data_endpoint: @data_endpoint
  }

  @con_tab_0 %{
    :free_mgmt_ids => @list_1_254,
    0 => @con_0
  }

  @con_tab_255 %{
    :free_mgmt_ids => @list_0_254,
    255 => @con_255
  }

  @con_tab_0_client_seq_1 %{
    :free_mgmt_ids => @list_1_254,
    0 => %C{@con_0 | client_seq_counter: 1}
  }

  @con_tab_0_client_seq_255 %{
    :free_mgmt_ids => @list_1_254,
    0 => %C{@con_0 | client_seq_counter: 255}
  }

  @con_tab_0_server_seq_1 %{
    :free_mgmt_ids => @list_1_254,
    0 => %C{@con_0 | server_seq_counter: 1}
  }

  @con_tab_0_server_seq_255 %{
    :free_mgmt_ids => @list_1_254,
    0 => %C{@con_0 | server_seq_counter: 255}
  }

  test "open: device management connection" do
    assert {:ok, %{:free_mgmt_ids => @list_1_254, 0 => @con_0}, 0} =
             ConTab.open(
               %{},
               :device_mgmt_con,
               %IpFrame{
                 control_endpoint: @control_endpoint,
                 data_endpoint: @data_endpoint
               }
             )

    assert {:error, :no_more_connections} =
             ConTab.open(
               %{:free_mgmt_ids => []},
               :device_mgmt_con,
               %IpFrame{
                 control_endpoint: @control_endpoint,
                 data_endpoint: @data_endpoint
               }
             )
  end

  test "open: tunneling connection" do
    assert {:ok, %{:free_mgmt_ids => @list_0_254, 255 => @con_255}, 255} =
             ConTab.open(
               %{},
               :tunnel_con,
               %IpFrame{
                 control_endpoint: @control_endpoint,
                 data_endpoint: @data_endpoint
               }
             )

    assert {:error, :no_more_connections} =
             ConTab.open(
               %{:free_mgmt_ids => @list_0_254, 255 => @con_255},
               :tunnel_con,
               %IpFrame{
                 control_endpoint: @control_endpoint,
                 data_endpoint: @data_endpoint
               }
             )
  end

  test "is connection open?" do
    assert true == ConTab.is_open?(@con_tab_0, 0)
    assert false == ConTab.is_open?(@con_tab_0, 1)
  end

  test "increment seq counter" do
    assert @con_tab_0_client_seq_1 = ConTab.increment_client_seq_counter(@con_tab_0, 0)
    assert @con_tab_0 = ConTab.increment_client_seq_counter(@con_tab_0_client_seq_255, 0)

    assert @con_tab_0_server_seq_1 = ConTab.increment_server_seq_counter(@con_tab_0, 0)
    assert @con_tab_0 = ConTab.increment_server_seq_counter(@con_tab_0_server_seq_255, 0)
  end

  test "is seq counter equal?" do
    assert true == ConTab.client_seq_counter_equal?(@con_tab_0, 0, 0)
    assert false == ConTab.client_seq_counter_equal?(@con_tab_0, 0, 7)

    assert true == ConTab.server_seq_counter_equal?(@con_tab_0, 0, 0)
    assert false == ConTab.server_seq_counter_equal?(@con_tab_0, 0, 58)
  end

  test "get seq counter" do
    assert 1 = ConTab.get_client_seq_counter(@con_tab_0_client_seq_1, 0)
    assert 255 = ConTab.get_server_seq_counter(@con_tab_0_server_seq_255, 0)
  end

  test "get endpoint" do
    assert @control_endpoint = ConTab.get_control_endpoint(@con_tab_0, 0)
    assert @data_endpoint = ConTab.get_data_endpoint(@con_tab_0, 0)
  end

  test "close connection" do
    assert {:error, :connection_id} = ConTab.close(@con_tab_0, 5)
    assert {:ok, %{:free_mgmt_ids => @list_0_254}} = ConTab.close(@con_tab_0, 0)
    assert {:ok, %{:free_mgmt_ids => @list_0_254}} = ConTab.close(@con_tab_255, 255)
  end
end
