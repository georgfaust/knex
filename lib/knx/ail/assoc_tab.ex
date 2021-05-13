defmodule Knx.Ail.AssocTab do
  alias Knx.Mem

  def get_object_type(), do: :addr_tab

  def get_assocs(asap: asap) do
    assoc_tab = Cache.get(:assoc_tab)
    Enum.filter(assoc_tab, fn {_, asap_} -> asap_ == asap end)
  end

  def get_assocs(tsap: tsap) do
    assoc_tab = Cache.get(:assoc_tab)
    Enum.filter(assoc_tab, fn {tsap_, _} -> tsap_ == tsap end)
  end

  def load(ref) do
    case Mem.read_table(ref, 4) do
      {:ok, _, table} ->
        table = for(<<tsap::16, asap::16 <- table>>, do: {tsap, asap})
        {:ok, Cache.put(:assoc_tab, table)}

      error ->
        error
    end
  end

  def unload(), do: {:ok, Cache.put(:assoc_tab, [0])}
end
