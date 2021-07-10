defmodule Knx.Stack.DlCemi do
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  def handle({:dl_cemi, :dn, %F{} = _frame}, %S{}) do
    :logger.debug("TODO DL CEMI DOWN")
    []
  end

  def handle({:dl_cemi, :up, cemi_frame}, %S{}) do
    :logger.debug("TODO DL CEMI UP: #{inspect(cemi_frame, base: :hex)}")
    []
  end
end
