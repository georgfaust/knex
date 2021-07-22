defmodule Knx.Ail.InterfaceProg do
  use Knx.LoadablePart, object_type: :interface_prog, mem_size: 100, unloaded_mem: <<>>

  alias Knx.Ail.Property, as: P
  require Knx.Defs
  import Knx.Defs

  @impl true
  def decode(mem) do
    mem
  end

  @impl true
  def load_complete(), do: {:ok, [{:control, :restart, :app}]}

  def get_props(mem_ref, prog_version) do
    [
      P.new(:object_type, [object_type(:interface_prog)], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:load_state_ctrl, [load_state(:unloaded)], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:prog_version, [prog_version], max: 1, write: false, r_lvl: 3, w_lvl: 0)
      # not mandatory -- aber sinnvoll um dl-zeit zu reduzieren (notwendig fuer part-prog?)
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
    ]
  end
end
