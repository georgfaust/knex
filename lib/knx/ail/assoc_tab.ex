defmodule Knx.Ail.AssocTab do
  alias Knx.Mem

  def get_assocs(assoc_tab, asap: asap),
    do: Enum.filter(assoc_tab, fn {_, asap_} -> asap_ == asap end)

  def get_assocs(assoc_tab, tsap: tsap),
    do: Enum.filter(assoc_tab, fn {tsap_, _} -> tsap_ == tsap end)

  def load(mem, ref) do
    {:ok, _, table} = Mem.read_table(mem, ref, 4)
    for <<tsap::16, asap::16 <- table>>, do: {tsap, asap}
  end
end
