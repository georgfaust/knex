defmodule Knx.Ail.GoTab do
  alias Knx.Ail.GroupObject
  alias Knx.Mem

  # TODO hack
  def get_object_index(), do: 4

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
    case Mem.read_table(ref, 2) do
      {:ok, _, table} ->
        table =
          for(<<descriptor::16 <- table>>, do: <<descriptor::16>>)
          |> Enum.with_index(1)
          |> Enum.map(fn {d, i} -> {i, GroupObject.new(d, i)} end)
          |> Enum.into(%{})

        {:ok, Cache.put(:go_tab, table)}

      error ->
        error
    end
  end

  def unload(), do: {:ok, Cache.put(:go_tab, [0])}

  # -----------------------------------------------------

  defp flag_set?(_, :any), do: true
  defp flag_set?(go, flag), do: Map.get(go, flag)
end
