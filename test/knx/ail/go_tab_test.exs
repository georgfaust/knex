defmodule Knx.Ail.GoTabTest do
  use ExUnit.Case

  import Knx.Ail.GoTab
  alias Knx.Ail.GroupObject

  @assoc_tab Helper.get_assoc_tab()

  @go_tab %{
    1 => %GroupObject{asap: 1, transmits: true, prio: 0, v_type: 0},
    2 => %GroupObject{asap: 2, writable: true, prio: 1, v_type: 1},
    3 => %GroupObject{asap: 3, readable: true, prio: 2, v_type: 2},
    4 => %GroupObject{asap: 4, updatable: true, prio: 3, v_type: 255},
    5 => %GroupObject{asap: 5, transmits: true, readable: true},
    6 => %GroupObject{asap: 6, transmits: true, readable: true, updatable: true}
  }

  #      u     t     i     w     r     c     prio  v_type
  @go1 <<0::1, 1::1, 0::1, 0::1, 0::1, 1::1, 0::2, 0x00::8>>
  @go2 <<0::1, 0::1, 0::1, 1::1, 0::1, 1::1, 1::2, 0x01::8>>
  @go3 <<0::1, 0::1, 0::1, 0::1, 1::1, 1::1, 2::2, 0x02::8>>
  @go4 <<1::1, 0::1, 0::1, 0::1, 0::1, 1::1, 3::2, 0xFF::8>>
  @go5 <<0::1, 1::1, 0::1, 0::1, 1::1, 1::1, 0::2, 0x00::8>>
  @go6 <<1::1, 1::1, 0::1, 0::1, 1::1, 1::1, 0::2, 0x00::8>>
  @mem <<6::16, @go1::bits, @go2::bits, @go3::bits, @go4::bits, @go5::bits, @go6::bits>>

  setup do
    Cache.start_link(%{mem: @mem})
    load(0)
    :ok
  end

  test "load" do
    assert {:ok, @go_tab} = load(0)
  end

  test "get all any" do
    assert [
             {1, %GroupObject{asap: 1}},
             {2, %GroupObject{asap: 2}},
             {3, %GroupObject{asap: 3}},
             {4, %GroupObject{asap: 4}},
             {5, %GroupObject{asap: 5}},
             {6, %GroupObject{asap: 6}}
           ] = get_all(@assoc_tab, :any)
  end

  test "get all transmitting" do
    assert [
             {1, %GroupObject{asap: 1}},
             {5, %GroupObject{asap: 5}},
             {6, %GroupObject{asap: 6}}
           ] = get_all(@assoc_tab, :transmits)
  end

  test "get all readable" do
    assert [
             {3, %GroupObject{asap: 3}},
             {5, %GroupObject{asap: 5}},
             {6, %GroupObject{asap: 6}}
           ] = get_all(@assoc_tab, :readable)
  end

  test "get all writable" do
    assert [{2, %GroupObject{asap: 2}}] = get_all(@assoc_tab, :writable)
  end

  test "get first any" do
    assert {:ok, {1, %GroupObject{asap: 1}}} = get_first(@assoc_tab, :any)
  end

  test "get first transmitting" do
    assert {:ok, {1, %GroupObject{asap: 1}}} = get_first(@assoc_tab, :transmits)
  end

  test "get first readable" do
    assert {:ok, {3, %GroupObject{asap: 3}}} = get_first(@assoc_tab, :readable)
  end

  test "get first writable" do
    assert {:ok, {2, %GroupObject{asap: 2}}} = get_first(@assoc_tab, :writable)
  end
end
