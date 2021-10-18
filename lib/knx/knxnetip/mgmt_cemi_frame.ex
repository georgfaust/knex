defmodule Knx.KnxnetIp.MgmtCemiFrame do
  @moduledoc """
  Struct for management cemi frames.

  message_code:     (see Defs.ex)
  object_type:      type of interface object
  object_instance:  instance of interface object
  pid:              property id
  elems:            number of elements
  start:            start index
  data:             property data
  """
  defstruct message_code: nil,
            object_type: nil,
            object_instance: nil,
            pid: nil,
            elems: nil,
            start: nil,
            data: <<>>
end
