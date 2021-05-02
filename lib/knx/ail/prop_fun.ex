defmodule Knx.Ail.PropertyFunction do
  @io_addr_tab 1
  @io_assoc_tab 2
  # @io_app_prog 3
  @io_go_tab 9

  @pid_load_state_control 5

  alias Knx.Ail.{Table, AddrTab, AssocTab, GoTab}

  def get_handler(o_idx, pid) do
    Map.fetch(
      %{
        {@io_addr_tab, @pid_load_state_control} => &Table.load_control(&1, &2, AddrTab),
        {@io_assoc_tab, @pid_load_state_control} => &Table.load_control(&1, &2, AssocTab),
        {@io_go_tab, @pid_load_state_control} => &Table.load_control(&1, &2, GoTab)
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
