defmodule Knx.Ail.PropertyFunction do
  @io_addr_tab 1
  @io_assoc_tab 2
  # @io_app_prog 3
  @io_go_tab 9

  @pid_load_state_ctrl 5

  alias Knx.Ail.{Table, AddrTab, AssocTab, GoTab}

  def get_handler(o_idx, pid) do
    Map.fetch(
      %{
        # TODO hack these are object indexes
        {1, @pid_load_state_ctrl} => &Table.load_ctrl(&1, &2, AddrTab),
        {2, @pid_load_state_ctrl} => &Table.load_ctrl(&1, &2, AssocTab),
        {3, @pid_load_state_ctrl} => &Table.load_ctrl(&1, &2, GoTab)
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
