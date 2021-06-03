defmodule Knx.Knxnetip.IpInterface do
  alias Knx.Knxnetip.Core
  alias Knx.Knxnetip.DeviceManagement
  alias Knx.Knxnetip.Tunnelling
  alias Knx.Knxnetip.IPFrame
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  import PureLogger
  require Knx.Defs
  import Knx.Defs
  use Bitwise

  def handle({:ip, :from_knx, %F{} = frame}, %S{}) do
    Tunnelling.handle_knx_frame(frame)
  end

  def handle({:ip, :from_ip, src, <<header::8*structure_length(:header), body::bits>>}, %S{}) do
    %IPFrame{ip_src: src}
    |> handle_header(<<header::8*structure_length(:header)>>)
    |> handle_body(body)
  end

  # ----------------------------------------------------------------------------

  defp handle_header(
         ip_frame,
         <<
           structure_length(:header)::8,
           protocol_version(:knxnetip)::8,
           service_type_id::16,
           total_length::16
         >>
       ) do
    %IPFrame{ip_frame | service_type_id: service_type_id, total_length: total_length}
  end

  defp handle_body(
         %IPFrame{service_type_id: service_type_id} = ip_frame,
         body
       ) do
    module =
      case service_type_id >>> 8 do
        service_family_id(:core) ->
          Core

        service_family_id(:device_management) ->
          DeviceManagement

        service_family_id(:tunnelling) ->
          Tunnelling

        _ ->
          error(:unknown_service_familiy)
      end

    module.handle_body(ip_frame, body)
  end
end
