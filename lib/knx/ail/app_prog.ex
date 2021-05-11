defmodule Knx.Ail.AppProg do
  alias Knx.Ail.Property, as: P
  @ls_unloaded 0
  @object_type_app_prog 3

  # TODO hack
  def get_object_index(), do: 3

  def get_table_ref() do
    props = Cache.get({:objects, get_object_index()})
    P.read_prop_value(props, :pid_table_reference)
  end

  def get_table_props(mem_ref, program_version) do
    [
      P.new(:pid_object_type, [@object_type_app_prog], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_load_state_ctrl, [@ls_unloaded], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_program_version, [program_version], max: 1, write: false, r_lvl: 3, w_lvl: 0)
      # not mandatory -- aber sinnvoll um dl-zeit zu reduzieren
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
    ]
  end
end
