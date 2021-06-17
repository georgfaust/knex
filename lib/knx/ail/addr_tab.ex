defmodule Knx.Ail.AddrTab do
  use Knx.LoadablePart, object_type: :addr_tab, mem_size: 100, unloaded_mem: [-1, 0]

  @impl true
  def decode(mem) do
    table = Knx.Ail.Table.get_table_bytes(mem, 2)
    # [X] tsaps are 1-based, add an invalid entry at index 0
    [-1] ++ for(<<addr::16 <- table>>, do: addr)
  end

  def get_tsap(group_addr) do
    table = Cache.get(@object_type)
    Enum.find_index(table, fn ga -> ga == group_addr end)
  end

  def get_group_addr(tsap) when tsap < 1, do: nil

  def get_group_addr(tsap) do
    table = Cache.get(@object_type)
    Enum.at(table, tsap)
  end
end
