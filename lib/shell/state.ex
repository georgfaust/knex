defmodule Shell.State do
  alias Knx.State, as: S

  defstruct driver_pid: nil,
            timer_pid: nil,
            core_state: %S{},
            serial: nil
end
