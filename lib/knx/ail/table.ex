defmodule Knx.Ail.Table do
  alias Knx.Ail.Property, as: P

  @ls_unloaded 0
  @ls_loaded 1

  def load_control(%{values: [load_state]}, [{event, data}], table_mod) do
    {new_load_state, action} = Knx.Ail.Lsm.dispatch(load_state, {event, data})

    case action do
      nil ->
        nil

      {:le_data_rel_alloc, [_req_mem_size, _mode, _fill]} ->
        # IO.inspect({"TODO action", :le_data_rel_alloc, [req_mem_size, mode, fill]})
        nil

      action ->
        IO.inspect({"unknown action", action})
    end

    # IO.inspect(new_load_state, label: :new_load_state)

    case new_load_state do
      @ls_unloaded -> table_mod.unload()
      @ls_loaded -> table_mod.load(get_table_ref(table_mod))
      _ -> nil
    end

    {:ok, [new_load_state]}
  end

  def load(table_mod) do
    ref = get_table_ref(table_mod)
    table_mod.load(ref)
  end

  def get_table_ref(table_mod) do
    props = Cache.get({:objects, table_mod.get_object_index()})
    P.read_prop_value(props, :pid_table_reference)
  end

  def get_table_props(object_type, mem_ref) do
    [
      P.new(:pid_object_type, [object_type], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_load_state_control, [@ls_unloaded], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0)
      # Table                 23 = PID_TABLE      PDT_UNSIGNED_INT[]
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
      # Error code            28 = PID_ERROR_CODE PDT_ENUM8
    ]
  end
end
