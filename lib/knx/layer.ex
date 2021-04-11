defmodule Knx.Stack do
  alias Knx.Frame, as: F

  @type layer_t :: :dl | :nl | :tl | :tlsm | :al
  @type primitive_t :: :ind | :req | :conf
  @type impulse_t :: {layer_t(), primitive_t(), F.t()}
end
