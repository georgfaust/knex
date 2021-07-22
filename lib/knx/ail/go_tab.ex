defmodule Knx.Ail.GoTab do
  use Knx.LoadablePart, object_type: :go_tab, mem_size: 100, unloaded_mem: [0]

  alias Knx.Ail.GroupObject

  @impl true
  def decode(mem) do
    table = Knx.Ail.Table.get_table_bytes(mem, 2)

    for(<<descriptor::16 <- table>>, do: <<descriptor::16>>)
    |> Enum.with_index(1)
    |> Enum.map(fn {d, i} -> {i, GroupObject.new(d, i)} end)
    |> Enum.into(%{})
  end

  # ---

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

  # ---

  defp flag_set?(_, :any), do: true
  defp flag_set?(go, flag), do: Map.get(go, flag)
end
