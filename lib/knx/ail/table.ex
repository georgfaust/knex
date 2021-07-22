defmodule Knx.Ail.Table do
  alias Knx.Ail.Property, as: P

  require Knx.Defs
  import Knx.Defs

  def get_table_bytes(<<length::16, mem::bytes>>, entry_size) do
    binary_part(mem, 0, length * entry_size)
  end

  def get_table_props(type, mem_ref) do
    [
      P.new(:object_type, [object_type(type)], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:load_state_ctrl, [load_state(:unloaded)], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(type, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], max: 256, write: true, r_lvl: 3, w_lvl: 2)
      # not mandatory -- aber sinnvoll um dl-zeit zu reduzieren
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
      # Error code            28 = PID_ERROR_CODE PDT_ENUM8
    ]
  end
end
