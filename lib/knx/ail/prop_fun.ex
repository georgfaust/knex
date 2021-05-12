defmodule Knx.Ail.PropertyFunction do
  require Knx.Defs
  import Knx.Defs

  alias Knx.Ail.{Table, AddrTab, AssocTab, GoTab}

  def get_handler(o_idx, pid) do
    Map.fetch(
      %{
        # TODO hack these are object indexes
        {1, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, AddrTab),
        {2, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, AssocTab),
        {3, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, GoTab)
      },
      {o_idx, pid}
    )
  end

  def handle(o_idx, pid, prop, data) do
    case get_handler(o_idx, pid) do
      {:ok, handler} -> handler.(prop, data)
      :error -> {:error, :cant_get_handler, {o_idx, pid}}
    end
  end
end
