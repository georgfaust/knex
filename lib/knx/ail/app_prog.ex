defmodule Knx.Ail.AppProg do
  alias Knx.Ail.Property, as: P
  require Knx.Defs
  import Knx.Defs

  def get_table_ref() do
    props = Cache.get_obj(:app_prog)
    P.read_prop_value(props, :table_reference)
  end

  def get_table_props(mem_ref, program_version) do
    [
      P.new(:object_type, [object_type(:app_prog)], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:load_state_ctrl, [load_state(:unloaded)], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:program_version, [program_version], max: 1, write: false, r_lvl: 3, w_lvl: 0)
      # not mandatory -- aber sinnvoll um dl-zeit zu reduzieren
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
    ]
  end
end
