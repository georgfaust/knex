defmodule Knx.Ail.GoTab do
  alias Knx.Ail.GroupObject
  alias Knx.Mem

  def get_first(assocs, flag) do
    assocs
    |> get_all(flag)
    |> Enum.fetch(0)
  end

  def get_all(assocs, flag) do
    go_tab = Cache.get(:go_tab)

    assocs
    |> Enum.map(fn {tsap, asap} -> {tsap, Map.get(go_tab, asap)} end)
    |> Enum.filter(fn {_, go} -> go && flag_set?(go, flag) end)
  end

  def load(ref) do
    {:ok, _, table} = Mem.read_table(ref, 2)

    go_tab =
      for(<<descriptor::16 <- table>>, do: <<descriptor::16>>)
      |> Enum.with_index(1)
      |> Enum.map(fn {d, i} -> {i, GroupObject.new(d, i)} end)
      |> Enum.into(%{})

    Cache.put(:go_tab, go_tab)
  end

  # -----------------------------------------------------

  defp flag_set?(_, :any), do: true
  defp flag_set?(go, flag), do: Map.get(go, flag)
end
