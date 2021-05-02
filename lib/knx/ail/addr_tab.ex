defmodule Knx.Ail.AddrTab do
  # [X] tsaps are 1-based, add an invalid entry at index 0
  @make_table_one_based [-1]
  @empty_table [-1, 0]

  alias Knx.Mem

  def get_object_index(), do: 1

  def get_tsap(group_addr) do
    table = Cache.get(:addr_tab)
    Enum.find_index(table, fn ga -> ga == group_addr end)
  end

  def get_group_addr(tsap) when tsap < 1, do: nil

  def get_group_addr(tsap) do
    table = Cache.get(:addr_tab)
    Enum.at(table, tsap)
  end

  def load(ref) do
    {:ok, _, table} = Mem.read_table(ref, 2)
    table = @make_table_one_based ++ for(<<addr::16 <- table>>, do: addr)
    Cache.put(:addr_tab, table)
  end

  def unload(), do: Cache.put(:addr_tab, @empty_table)
end
