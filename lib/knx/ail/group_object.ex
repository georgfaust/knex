defmodule Knx.Ail.GroupObject do
  defstruct asap: nil,
            transmits: false,
            writable: false,
            readable: false,
            updatable: false,
            read_on_init: false,
            prio: 0,
            v_type: 0

  # [XII]
  def new(<<u::1, t::1, i::1, w::1, r::1, c::1, prio::2, v_type::8>>, asap) do
    %__MODULE__{
      asap: asap,
      transmits: c == 1 && t == 1,
      writable: c == 1 && w == 1,
      readable: c == 1 && r == 1,
      updatable: c == 1 && u == 1,
      read_on_init: c == 1 && i == 1,
      prio: prio,
      v_type: v_type
    }
  end

  # [XIII]
  def value_size(v_type) when v_type <= 6, do: {1, v_type + 1}
  def value_size(v_type), do: {8, v_type - 6}
end
