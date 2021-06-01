defmodule Knx.Knxnetip.ConTabTest do
  use ExUnit.Case

  alias Knx.Knxnetip.ConTab
  alias Knx.Knxnetip.Connection, as: C

  @list_1_254 Enum.to_list(1..254)
  @con_0 %C{id: 0, con_type: :device_mgmt_con, dest_data_endpoint: {0xC0A8_B23E, 0x0E75}}
  @con_1 %C{id: 0, con_type: :device_mgmt_con, dest_data_endpoint: {0xC0A8_B23E, 0x0E76}}

  @con_tab_01 %{
    :free_mgmt_ids => Enum.to_list(2..255),
    0 => @con_0,
    1 => @con_1
  }

  @con_tab_0 %{
    :free_mgmt_ids => Enum.to_list(1..255),
    0 => @con_0
  }

  @con_tab_0_seq_1 %{
    :free_mgmt_ids => Enum.to_list(1..255),
    0 => %C{@con_0 | ext_seq_counter: 1}
  }

  @con_tab_0_seq_255 %{
    :free_mgmt_ids => Enum.to_list(1..255),
    0 => %C{@con_0 | ext_seq_counter: 255}
  }

  # TODO adapt tests to new functions
  test "open" do
    assert {%{:free_mgmt_ids => @list_1_254, 0 => @con_0}, 0} =
             ConTab.open(%{}, :device_mgmt_con, {0xC0A8_B23E, 0x0E75})

    assert {%{:free_mgmt_ids => []}, {:error, :no_more_connections}} =
             ConTab.open(%{:free_mgmt_ids => []}, :device_mgmt_con, {0xC0A8_B23E, 0x0E75})
  end

  test "is open?" do
    assert true == ConTab.is_open?(@con_tab_0, 0)
    assert false == ConTab.is_open?(@con_tab_0, 1)
  end

  test "increment external sequence counter" do
    assert @con_tab_0_seq_1 = ConTab.increment_ext_seq_counter(@con_tab_0, 0)
    assert @con_tab_0 = ConTab.increment_ext_seq_counter(@con_tab_0_seq_255, 0)
  end

  test "external sequence counter correct?" do
    assert true == ConTab.ext_seq_counter_equal?(@con_tab_0_seq_1, 0, 1)
    assert false == ConTab.ext_seq_counter_equal?(@con_tab_0_seq_255, 0, 0)
  end

  # test "close" do
  #   assert {@con_tab_01, {:error, :connection_id}} = ConTab.close(@con_tab_01, 5)
  #   assert {@con_tab_0, 1} = ConTab.close(@con_tab_01, 1)
  # end
end
