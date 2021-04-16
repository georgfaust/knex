defmodule Knx.Ail.AddrTab do
  # [X] tsaps are 1-based, add an invalid entry at index 0
  @make_table_one_based [-1]

  alias Knx.Mem

  def get_tsap(table, group_addr),
    do: Enum.find_index(table, fn ga -> ga == group_addr end)

  def get_group_addr(_, tsap) when tsap < 1, do: nil
  def get_group_addr(table, tsap), do: Enum.at(table, tsap)

  def load(mem, ref) do
    {:ok, _, table} = Mem.read_table(mem, ref, 2)
    @make_table_one_based ++ for(<<addr::16 <- table>>, do: addr)
  end
end
