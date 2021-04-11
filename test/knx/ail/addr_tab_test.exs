defmodule Knx.Ail.AddrTabTest do
  use ExUnit.Case
  import Knx.Ail.AddrTab

  @mem <<0::unit(8)-size(4), 5::16, 10::16, 20::16, 30::16, 40::16, 50::16>>
  @addr_tab [-1, 10, 20, 30, 40, 50]

  test "addr tab" do
    assert @addr_tab == load(@mem, 4)
  end

  test "get tsap" do
    assert 1 == get_tsap(@addr_tab, 10)
    assert 5 == get_tsap(@addr_tab, 50)
    assert nil == get_tsap(@addr_tab, 0)
    assert nil == get_tsap(@addr_tab, 99)
  end

  test "get addr" do
    assert 10 == get_group_addr(@addr_tab, 1)
    assert 50 == get_group_addr(@addr_tab, 5)
    assert nil == get_group_addr(@addr_tab, 0)
    assert nil == get_group_addr(@addr_tab, 6)
  end
end
