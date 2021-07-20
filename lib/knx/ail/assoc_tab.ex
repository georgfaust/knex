defmodule Knx.Ail.AssocTab do
  use Knx.LoadablePart, object_type: :assoc_tab, mem_size: 100, unloaded_mem: [0]

  @impl true
  def decode(mem) do
    table = Knx.Ail.Table.get_table_bytes(mem, 4)
    for(<<tsap::16, asap::16 <- table>>, do: {tsap, asap})
  end

  def get_assocs(asap: asap) do
    assoc_tab = Cache.get(:assoc_tab)
    Enum.filter(assoc_tab, fn {_, asap_} -> asap_ == asap end)
  end

  def get_assocs(tsap: tsap) do
    assoc_tab = Cache.get(:assoc_tab)
    Enum.filter(assoc_tab, fn {tsap_, _} -> tsap_ == tsap end)
  end
end
