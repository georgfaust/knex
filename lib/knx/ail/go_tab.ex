defmodule Knx.Ail.GoTab do
  alias Knx.Ail.GroupObject
  alias Knx.Mem

  def get_first(assocs, go_tab, flag) do
    assocs
    |> get_all(go_tab, flag)
    |> Enum.fetch(0)
  end

  def get_all(assocs, go_tab, flag) do
    assocs
    |> Enum.map(fn {tsap, asap} -> {tsap, Map.get(go_tab, asap)} end)
    |> Enum.filter(fn {_, go} -> go && flag_set?(go, flag) end)
  end

  def load(mem, ref) do
    {:ok, _, table} = Mem.read_table(mem, ref, 2)

    for(<<descriptor::16 <- table>>, do: <<descriptor::16>>)
    |> Enum.with_index(1)
    |> Enum.map(fn {d, i} -> {i, GroupObject.new(d, i)} end)
    |> Enum.into(%{})
  end

  # -----------------------------------------------------

  defp flag_set?(_, :any), do: true
  defp flag_set?(go, flag), do: Map.get(go, flag)
end
