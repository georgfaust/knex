defmodule Knx.Ail.AssocTab do
  alias Knx.Mem

  def get_assocs(asap: asap) do
    assoc_tab = Cache.get(:assoc_tab)
    Enum.filter(assoc_tab, fn {_, asap_} -> asap_ == asap end)
  end

  def get_assocs(tsap: tsap) do
    assoc_tab = Cache.get(:assoc_tab)
    Enum.filter(assoc_tab, fn {tsap_, _} -> tsap_ == tsap end)
  end

  def load(ref) do
    {:ok, _, table} = Mem.read_table(ref, 4)
    assoc_tab = for(<<tsap::16, asap::16 <- table>>, do: {tsap, asap})
    Cache.put(:assoc_tab, assoc_tab)
  end
end
