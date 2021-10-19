defmodule Knx.KnxnetIp.ConTabTest do
  use ExUnit.Case

  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.KnipFrame
  alias Knx.KnxnetIp.Endpoint, as: Ep

  @knx_indv_addr 0x11FF

  @control_endpoint %Ep{ip_addr: {192, 168, 178, 62}, port: 3701}
  @data_endpoint %Ep{ip_addr: {192, 168, 178, 62}, port: 3701}

  @list_0_255 Enum.to_list(0..255)
  @list_1_255 Enum.to_list(1..255)
  @list_2_255 Enum.to_list(2..255)

  @con_mgmt %C{
    id: 0,
    con_type: :device_mgmt_con,
    dest_control_endpoint: @control_endpoint,
    dest_data_endpoint: @data_endpoint,
    client_seq_counter: 0,
    server_seq_counter: 0
  }

  @con_tunnel %C{
    id: 1,
    con_type: :tunnel_con,
    dest_control_endpoint: @control_endpoint,
    dest_data_endpoint: @data_endpoint,
    con_knx_indv_addr: @knx_indv_addr,
    client_seq_counter: 0,
    server_seq_counter: 0
  }

  @con_tab_0 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{},
    :tunnel_cons_left => 1,
    0 => @con_mgmt
  }

  @con_tab_1 %{
    :free_ids => @list_2_255,
    :tunnel_cons => %{@knx_indv_addr => 1},
    :tunnel_cons_left => 0,
    0 => @con_mgmt,
    1 => @con_tunnel
  }

  @con_tab_0_client_seq_1 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{},
    :tunnel_cons_left => 1,
    0 => %C{@con_mgmt | client_seq_counter: 1}
  }

  @con_tab_0_client_seq_255 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{},
    :tunnel_cons_left => 1,
    0 => %C{@con_mgmt | client_seq_counter: 255}
  }

  @con_tab_0_server_seq_1 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{},
    :tunnel_cons_left => 1,
    0 => %C{@con_mgmt | server_seq_counter: 1}
  }

  @con_tab_0_server_seq_255 %{
    :free_ids => @list_1_255,
    :tunnel_cons => %{},
    :tunnel_cons_left => 1,
    0 => %C{@con_mgmt | server_seq_counter: 255}
  }

  test "open: device management connection" do
    assert {:ok, @con_tab_0, 0} =
             ConTab.open(
               %{},
               :device_mgmt_con,
               %KnipFrame{
                 control_endpoint: @control_endpoint,
                 data_endpoint: @data_endpoint
               }
             )

    assert {:error, :no_more_connections} =
             ConTab.open(
               %{:free_ids => []},
               :device_mgmt_con,
               %KnipFrame{
                 control_endpoint: @control_endpoint,
                 data_endpoint: @data_endpoint
               }
             )
  end

  test "open: tunneling connection" do
    assert {:ok, @con_tab_1, 1} =
             ConTab.open(
               @con_tab_0,
               :tunnel_con,
               %KnipFrame{
                 control_endpoint: @control_endpoint,
                 data_endpoint: @data_endpoint,
                 con_knx_indv_addr: @knx_indv_addr
               }
             )

    assert {:error, :no_more_connections} =
             ConTab.open(
               @con_tab_1,
               :tunnel_con,
               %KnipFrame{
                 control_endpoint: @control_endpoint,
                 data_endpoint: @data_endpoint,
                 con_knx_indv_addr: @knx_indv_addr
               }
             )
  end

  test "close connection" do
    assert {:error, :connection_id} = ConTab.close(@con_tab_0, 5)
    assert {:ok, %{:free_ids => @list_0_255}} = ConTab.close(@con_tab_0, 0)
    assert {:ok, @con_tab_0} = ConTab.close(@con_tab_1, 1)
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

  test "compare client seq counter" do
    assert :counter_equal == ConTab.compare_client_seq_counter(@con_tab_0, 0, 0)
    assert :counter_off_by_minus_one == ConTab.compare_client_seq_counter(@con_tab_0, 0, 255)
    assert :any_other_case == ConTab.compare_client_seq_counter(@con_tab_0, 0, 10)
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
end
