defmodule Knx.KnxnetIp.IpInterface do
  alias Knx.KnxnetIp.Core
  alias Knx.KnxnetIp.DeviceManagement
  alias Knx.KnxnetIp.Tunnelling
  alias Knx.KnxnetIp.IpFrame
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  import PureLogger
  require Knx.Defs
  import Knx.Defs
  use Bitwise

  def handle({:ip, :from_knx, %F{} = frame}, %S{}) do
    Tunnelling.handle_knx_frame(frame)
  end

  def handle({:ip, :from_ip, src, <<header::bytes-structure_length(:header), body::bits>>}, %S{}) do
    %IpFrame{ip_src: src}
    |> handle_header(header)
    |> handle_body(body)
  end

  # ----------------------------------------------------------------------------

  defp handle_header(
         ip_frame,
         <<
           structure_length(:header)::8,
           protocol_version(:knxnetip)::8,
           service_family_id::8,
           service_type_id::8,
           total_length::16
         >>
       ) do
    %IpFrame{
      ip_frame
      | service_family_id: service_family_id,
        service_type_id: service_type_id,
        total_length: total_length
    }
  end

  defp handle_body(
         %IpFrame{service_family_id: service_family_id} = ip_frame,
         body
       ) do
    case service_family_id do
      service_family_id(:core) ->
        Core.handle_body(ip_frame, body)

      service_family_id(:device_management) ->
        DeviceManagement.handle_body(ip_frame, body)

      service_family_id(:tunnelling) ->
        Tunnelling.handle_body(ip_frame, body)

      _ ->
        error(:unknown_service_familiy)
    end
  end

  # ----------------------------------------------------------------------------

  def header(service_type_id, total_length) do
    <<
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      get_service_family_id(service_type_id)::8,
      service_type_id::8,
      total_length::16
    >>
  end

  # ----------------------------------------------------------------------------

  defp get_service_family_id(service_type_id) do
    # service families have non-overlapping service type number ranges
    cond do
      service_type_id <= 0x0F -> service_family_id(:core)
      service_type_id <= 0x1F -> service_family_id(:device_management)
      service_type_id <= 0x2F -> service_family_id(:tunnelling)
    end
  end
end
