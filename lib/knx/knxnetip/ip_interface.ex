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

  # !info: keep service_type_id as only field in IpFrame struct, since
  # no name for lower octet of service type id is defined in knx standard
  # and apart from code in this module, only full service type id is needed
  # Instead, use function to retrieve service family from service type id
  defp handle_header(
         ip_frame,
         <<
           structure_length(:header)::8,
           protocol_version(:knxnetip)::8,
           service_type_id::16,
           total_length::16
         >>
       ) do
    %IpFrame{
      ip_frame
      | service_type_id: service_type_id,
        total_length: total_length
    }
  end

  defp handle_body(
         %IpFrame{service_type_id: service_type_id} = ip_frame,
         body
       ) do
    case get_service_familiy(service_type_id) do
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
      service_type_id::16,
      total_length::16
    >>
  end

  # ----------------------------------------------------------------------------

  def get_service_familiy(service_type_id) do
    # service family = high octet of service type id
    service_type_id >>> 8
  end
end
