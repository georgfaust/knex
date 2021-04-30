defmodule Knx.Ail.AssocTabTest do
  use ExUnit.Case
  import Knx.Ail.AssocTab

  @mem <<
    0::unit(8)-size(4),
    5::16,
    1::16,
    1::16,
    2::16,
    1::16,
    2::16,
    2::16,
    3::16,
    2::16,
    1::16,
    3::16
  >>

  @assoc_tab [
    {1, 1},
    {2, 1},
    {2, 2},
    {3, 2},
    {1, 3}
  ]
  setup do
    Cache.start_link(%{mem: @mem})
    load(4)
    :ok
  end

  test "load" do
    assert @assoc_tab = load(4)
  end

  test "get by asap" do
    assert [{1, 1}, {2, 1}] = get_assocs(asap: 1)
    assert [{1, 3}] = get_assocs(asap: 3)
    assert [] = get_assocs(asap: 99)
  end

  test "get by tsap" do
    assert [{1, 1}, {1, 3}] = get_assocs(tsap: 1)
    assert [{3, 2}] = get_assocs(tsap: 3)
    assert [] = get_assocs(tsap: 99)
  end
end
