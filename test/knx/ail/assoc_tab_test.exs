defmodule Knx.Ail.AssocTabTest do
  use ExUnit.Case
  import Knx.Ail.AssocTab

  @ref_assoc_tab 4
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
    3::16,
    0::800
  >>

  @assoc_tab [
    {1, 1},
    {2, 1},
    {2, 2},
    {3, 2},
    {1, 3}
  ]
  setup do
    Cache.start_link(%{
      objects: [assoc_tab: Knx.Ail.Table.get_table_props(:assoc_tab, @ref_assoc_tab)],
      mem: @mem
    })

    load()

    :ok
  end

  test "load" do
    assert {:ok, []} == load()
    assert @assoc_tab = Cache.get(:assoc_tab)
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
