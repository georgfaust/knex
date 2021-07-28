defmodule Knx.Stack.Dl do
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  def handle({:dl, :req, %F{} = frame}, %S{}) do
    frame = Knx.DataCemiFrame.encode(:req, frame)
    # TODO for KNX-IP-device: call Knx.KnxnetIp.Routing.enqueue(frame)
    [{:driver, :transmit, frame}]
  end

  def handle({:dl, :up, frame}, %S{}) do
    {primitive, frame} = Knx.DataCemiFrame.decode(frame)
    # :logger.debug("DL_CEMI UP #{inspect {prim, frame}}")
    if primitive do
      [{:nl, primitive, frame}]
    else
      []
    end
  end
end
