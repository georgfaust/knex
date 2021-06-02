defmodule Knx.Knxnetip.IpInterface do
  alias Knx.Knxnetip.Core
  alias Knx.Knxnetip.DeviceManagement
  alias Knx.Knxnetip.Tunneling
  alias Knx.Knxnetip.IPFrame
  alias Knx.State, as: S

  import PureLogger
  require Knx.Defs
  import Knx.Defs
  use Bitwise

  def handle({:ip, :from_ip, src, data}, %S{}) do

    {ip_frame, body} = handle_header(data)

    module =
      cond do
        ip_frame.service_type_id >>> 8 == service_family_id(:core) ->
          Core

        ip_frame.service_type_id >>> 8 == service_family_id(:device_management) ->
          DeviceManagement

        ip_frame.service_type_id >>> 8 == service_family_id(:tunneling) ->
          Tunneling

        true ->
          error(:unknown_service_familiy)
      end

    module.handle_body(src, ip_frame, body)
  end

  # ----------------------------------------------------------------------------

  defp handle_header(<<
         structure_length(:header)::8,
         protocol_version(:knxnetip)::8,
         service_type_id::16,
         total_length::16,
         body::bits
       >>) do
    ip_frame = %IPFrame{
      service_type_id: service_type_id,
      total_length: total_length
    }

    {ip_frame, body}
  end
end
