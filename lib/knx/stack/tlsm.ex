defmodule Knx.Stack.Tlsm do
  alias Knx.State, as: S
  alias Knx.Frame, as: F
  alias Knx.Stack.Tlsm.{Sm, Action, Event}

  def handle({:tlsm, primitive, %F{service: service} = frame}, %S{} = state)
      when service in [:t_data_group, :t_data_ind, :t_data_broadcast] do
    next =
      case primitive do
        :req -> :tl
        :ind -> :al
        :conf -> :al
      end

    {state, [{next, primitive, frame}]}
  end

  def handle({:tlsm, primitive, %F{service: service} = frame}, %S{handler: handler} = state) do
    tran(handler, primitive, service, frame, state)
  end

  def handle({:tlsm, :timeout, timer}, %S{handler: handler} = state) do
    tran(handler, :timeout, timer, %F{}, state)
  end

  defp tran(handler, typ, par, frame, state) do
    event = Event.get_event(typ, par, frame, state)
    {new_handler, action} = Sm.state_handler(event, handler)

    # TODO check closed entry and delete stored and deferred, seqs should be handled by actions!?

    :logger.info("[D: #{Process.get(:cache_id)}] (#{handler}) --[#{event}/#{action}]--> (#{new_handler})")

    Action.action(action, %S{state | handler: new_handler}, frame)
  end
end
