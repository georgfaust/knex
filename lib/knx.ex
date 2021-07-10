defmodule Knx do
  alias Knx.State, as: S
  alias Knx.Stack.{Dl, DlCemi, Nl, Tl, Tlsm, Al}
  alias Knx.Ail.GoServer, as: GO
  alias Knx.Ail.IoServer, as: IO
  alias Knx.{Mem, Restart}

  def append_effect(effect, %S{pending_effects: pending_effects} = state) do
    {%S{state | pending_effects: pending_effects ++ [effect]}, []}
  end

  def handle_impulse(%S{} = state, {target, _, _} = impulse) do
    handle =
      Map.fetch!(
        %{
          dl: &Dl.handle/2,
          dl_cemi: &DlCemi.handle/2,
          nl: &Nl.handle/2,
          tl: &Tl.handle/2,
          tlsm: &Tlsm.handle/2,
          al: &Al.handle/2,
          go: &GO.handle/2,
          io: &IO.handle/2,
          restart: &Restart.handle/2,
          mem: &Mem.handle/2,
          auth: &Knx.Auth.handle/2,
          timer: &append_effect/2,
          driver: &append_effect/2,
          mgmt: &append_effect/2,
          logger: &append_effect/2,
          app: &append_effect/2
        },
        target
      )

    :logger.debug("[D: #{Process.get(:cache_id)}] #{inspect(impulse)}")

    case handle.(impulse, state) do
      {%S{} = new_state, new_impulses} -> {new_state, new_impulses}
      new_impulses -> {state, new_impulses}
    end
  end

  def handle_impulses(%S{} = state, [impulse | impulses]) do
    {state, new_impulses} = handle_impulse(state, impulse)
    handle_impulses(state, impulses ++ new_impulses)
  end

  def handle_impulses(%S{pending_effects: effects} = state, []),
    do: {effects, %S{state | pending_effects: []}}
end
