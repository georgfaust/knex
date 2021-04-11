defmodule Knx.Stack.Tlsm do
  alias Knx.State, as: S
  alias Knx.Frame, as: F
  alias Knx.Stack.Tlsm.{Sm, Action, Event}

  @spec handle(Knx.impulse_t(), S.t()) :: {S.t(), [Knx.impulse_t()]}

  def handle({:tlsm, primitive, %F{service: :t_data_group} = frame}, %S{} = state) do
    next =
      case primitive do
        :req -> :tl
        :ind -> :al
        :conf -> :al
      end

    {state, [{next, primitive, frame}]}
  end

  def handle({:tlsm, primitive, %F{service: service} = frame}, %S{handler: handler} = state) do
    event = Event.get_event(primitive, service, frame, state)
    {new_handler, action} = Sm.state_handler(event, handler)
    # IO.inspect({handler, event, new_handler, action})
    Action.action(action, %S{state | handler: new_handler}, frame)
  end

  def handle({:tlsm, :timeout, timer}, %S{handler: handler} = state) do
    event = Event.get_event(:timeout, timer, %F{}, state)
    {new_handler, action} = Sm.state_handler(event, handler)
    # IO.inspect({handler, event, new_handler, action})
    Action.action(action, %S{state | handler: new_handler}, %F{})
  end
end
