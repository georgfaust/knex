defmodule Knx do
  alias Knx.State, as: S
  alias Knx.Timer
  alias Knx.Stack.{Dl, Nl, Tl, Tlsm, Al}
  alias Knx.Ail.GoServer, as: GO
  alias Knx.Ail.IoServer, as: IO
  alias Knx.Mem

  def append_effect(effect, %S{pending_effects: pending_effects} = state) do
    {%S{state | pending_effects: pending_effects ++ [effect]}, []}
  end

  def handle_impulse(%S{} = state, {target, _, _} = impulse) do
    handle =
      Map.fetch!(
        %{
          dl: &Dl.handle/2,
          nl: &Nl.handle/2,
          tl: &Tl.handle/2,
          tlsm: &Tlsm.handle/2,
          al: &Al.handle/2,
          # TODO
          go: &GO.handle/2,
          # TODO
          io: &IO.handle/2,
          # TODO
          mem: &Mem.handle/2,
          timer: &append_effect/2,
          driver: &append_effect/2,
          user: &append_effect/2,
          logger: &append_effect/2,
          todo: &append_effect/2
        },
        target
      )

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

  def proftest do
    Enum.each(1..1_000_000, fn _ ->
      Knx.handle_impulses(
        %S{addr: 100, handler: :closed},
        [{:al, :req, %Knx.Frame{dest: 200, service: :t_connect}}]
      )
    end)
  end
end
