defmodule Knx.Ail.PropertyFunction do
  require Knx.Defs
  import Knx.Defs

  alias Knx.Ail.{AddrTab, AssocTab, GoTab, AppProg}

  def get_handler(o_idx, pid) do
    Map.fetch(
      %{
        # TODO hack these are object indexes
        # --> get object-type from props
        {1, prop_id(:load_state_ctrl)} => &AddrTab.load_ctrl(&1, &2),
        {2, prop_id(:load_state_ctrl)} => &AssocTab.load_ctrl(&1, &2),
        {3, prop_id(:load_state_ctrl)} => &GoTab.load_ctrl(&1, &2),
        {4, prop_id(:load_state_ctrl)} => &AppProg.load_ctrl(&1, &2)
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
