defmodule Knx.Ail.Table do
  alias Knx.Ail.Property, as: P

  @ls_unloaded 0
  @ls_loaded 1

  @load_state_error 3

  def new_load_state_action(new_load_state, table_mod) do
    case new_load_state do
      @ls_unloaded -> table_mod.unload()
      @ls_loaded -> table_mod.load(get_table_ref(table_mod))
      _ -> {:ok, nil}
    end
  end

  def load_ctrl(%{values: [load_state]}, [{event, data}], table_mod) do
    {new_load_state, action} = Knx.Ail.Lsm.dispatch(load_state, {event, data})

    IO.inspect({load_state, event, new_load_state, action})

    case action do
      nil ->
        nil

      {:le_data_rel_alloc, [_req_mem_size, _mode, _fill]} ->
        # IO.inspect({"TODO action", :le_data_rel_alloc, [req_mem_size, mode, fill]})
        nil

      action ->
        IO.inspect({"unknown action", action})
    end

    case new_load_state_action(new_load_state, table_mod) do
      {:ok, _} -> {:ok, [new_load_state]}
      {:error, _} -> {:error, [@load_state_error]}
      unexpected -> raise(inspect {:unexpected, unexpected})
    end
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
      P.new(:pid_load_state_ctrl, [@ls_unloaded], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0)
      # TODO -- ?? siehe notes
      # Table                 23 = PID_TABLE      PDT_UNSIGNED_INT[]
      # not mandatory -- aber sinnvoll um dl-zeit zu reduzieren
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
      # Error code            28 = PID_ERROR_CODE PDT_ENUM8
    ]
  end
end
