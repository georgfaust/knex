defmodule Knx.KnxnetIp.Endpoint do
  @moduledoc """
  Struct for endpoints.

  Endpoints are the logical view of HPAIs.

  Every KNXnet/IP device may support multiple endpoints for certain
  well defined purposes.

  KNeX currently supports only a single endpoint for the server.

  protocol_code:    code of either :udp or :tcp (use protocol_code())
  ip_addr:          4-tuple of ip address (one element per byte)
  port:             port number
  """
  defstruct protocol_code: nil,
            ip_addr: nil,
            port: nil
end
