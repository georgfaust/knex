defmodule Knx.Ail.PropertyFunction do
  require Knx.Defs
  import Knx.Defs

  alias Knx.Ail.{Table, AddrTab, AssocTab, GoTab, AppProg}

  def get_handler(o_idx, pid) do
    Map.fetch(
      %{
        # TODO hack these are object indexes -- see notes, its not clear if these are standardized ...
        {1, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, AddrTab),
        {2, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, AssocTab),
        {3, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, GoTab),
        # {4, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, AppProg),
        # {5, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, AppProg)

        # HACK
        {5, prop_id(:load_state_ctrl)} => &Table.load_ctrl(&1, &2, AddrTab),

      },
      {o_idx, pid}
    )
  end

  def handle(o_idx, pid, prop, data) do
    case get_handler(o_idx, pid) do
      {:ok, handler} ->
        handler.(prop, data)
      :error ->
        raise("#{inspect {:error, :cant_get_handler, {o_idx, pid}}}")
        # {:error, :cant_get_handler, {o_idx, pid}}
    end
  end
end
