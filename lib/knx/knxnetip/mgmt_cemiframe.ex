defmodule Knx.KnxnetIp.MgmtCemiFrame do
  defstruct message_code: nil,
            object_type: nil,
            object_instance: nil,
            pid: nil,
            elems: nil,
            start: nil,
            data: <<>>
end
