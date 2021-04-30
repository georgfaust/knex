defmodule Knx.Ail.AddrTabTest do
  use ExUnit.Case
  import Knx.Ail.AddrTab

  @mem <<0::unit(8)-size(4), 5::16, 10::16, 20::16, 30::16, 40::16, 50::16>>
  @addr_tab [-1, 10, 20, 30, 40, 50]

  setup do
    Cache.start_link(%{addr_tab: @addr_tab, mem: @mem})
    :ok
  end

  test "addr tab" do
    assert @addr_tab == load(4)
  end

  test "get tsap" do
    assert 1 == get_tsap(10)
    assert 5 == get_tsap(50)
    assert nil == get_tsap(0)
    assert nil == get_tsap(99)
  end

  test "get addr" do
    assert 10 == get_group_addr(1)
    assert 50 == get_group_addr(5)
    assert nil == get_group_addr(0)
    assert nil == get_group_addr(6)
  end
end
