defmodule Knx.Ail.Table do
  alias Knx.Ail.Property, as: P

  require Knx.Defs
  import Knx.Defs

  def new_load_state_action(new_load_state, table_mod) do
    result =
      case new_load_state do
        load_state(:unloaded) -> table_mod.unload()
        load_state(:loaded) -> table_mod.load(get_table_ref(table_mod))
        _ -> {:ok, nil}
      end
    :logger.info("new_load_state_action: #{inspect new_load_state} -> #{inspect result}")
    result
  end

  def load_ctrl(%{values: [load_state]}, [{event, data}], table_mod) do
    {new_ls, action} = Knx.Ail.Lsm.dispatch(load_state, {event, data})

    case action do
      nil ->
        nil

      {:alc_data_rel_alloc, [req_mem_size, mode, fill]} ->
        raise("#{inspect({"TODO action", :alc_data_rel_alloc, [req_mem_size, mode, fill]})}")

      action ->
        IO.inspect({"unknown action", action})
    end

    case new_load_state_action(new_ls, table_mod) do
      {:ok, _} -> {:ok, [new_ls]}
      {:error, _} -> {:error, [load_state(:error)]}
      unexpected -> raise(inspect({:unexpected, unexpected}))
    end
  end

  def load(table_mod) do
    ref = get_table_ref(table_mod)
    table_mod.load(ref)
  end

  def get_table_ref(table_mod) do
    props = Cache.get_obj(table_mod.get_object_type())
    P.read_prop_value(props, :table_reference)
  end

  def get_table_props(type, mem_ref) do
    [
      P.new(:object_type, [object_type(type)], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:load_state_ctrl, [load_state(:unloaded)], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(type, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], max: 256, write: true, r_lvl: 3, w_lvl: 2)
      # not mandatory -- aber sinnvoll um dl-zeit zu reduzieren ...?
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
      # Error code            28 = PID_ERROR_CODE PDT_ENUM8
    ]
  end
end
