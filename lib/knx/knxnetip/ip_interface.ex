defmodule Knx.KnxnetIp.IpInterface do
  alias Knx.KnxnetIp.Core
  alias Knx.KnxnetIp.DeviceManagement
  alias Knx.KnxnetIp.Tunnelling
  alias Knx.KnxnetIp.Routing
  alias Knx.KnxnetIp.IpFrame
  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState

  import PureLogger
  require Knx.Defs
  import Knx.Defs
  use Bitwise

  def handle(
        {:knip, :from_ip,
         {ip_src_endpoint, <<header::bytes-structure_length(:header), body::bits>>}},
        %S{knxnetip: ip_state} = state
      ) do
    {ip_state, impulses} =
      %IpFrame{ip_src_endpoint: ip_src_endpoint}
      |> handle_header(header)
      |> check_length(body)
      |> handle_body(body, ip_state)

    {%{state | knxnetip: ip_state}, impulses}
  end

  # TODO is this correct? instead of %F{}, impulse includes binary
  def handle({:knip, :from_knx, data_cemi_frame}, %S{knxnetip: ip_state} = state) do
    {ip_state, impulses} = Tunnelling.handle_up_frame(data_cemi_frame, ip_state)
    {%{state | knxnetip: ip_state}, impulses}
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

  # -- Core, 6.2: "If a server receives a data packet with an unsupported version field,
  # it shall reply with a negative confirmation frame indicating in the status
  # field E_VERSION_NOT_SUPPORTED."
  # Was ist ein NACK für KNXnet/IP? ACK mit Error im Status? Wenn ja, welches ACK?
  # Aktuell gibt es nur die Version 1.0 für alle Frames (auch in ANs in KNX 2.1.4)
  # Hier erstmal: Frames mit falscher Version ignorieren (Der Regel folgend,
  # dass invalide Frames ignoriert werden sollen.)
  defp handle_header(ip_frame, _frame) do
    warning(:invalid_header)
    ip_frame
  end

  # ----------------------------------------------------------------------------

  defp check_length(%IpFrame{total_length: total_length} = ip_frame, body) do
    if total_length != structure_length(:header) + byte_size(body) do
      warning(:invalid_total_length)
    end

    ip_frame
  end

  # ----------------------------------------------------------------------------

  defp handle_body(
         %IpFrame{service_family_id: service_family_id(:core)} = ip_frame,
         body,
         %IpState{} = ip_state
       ) do
    Core.handle_body(ip_frame, body, ip_state)
  end

  defp handle_body(
         %IpFrame{service_family_id: service_family_id(:device_management)} = ip_frame,
         body,
         %IpState{} = ip_state
       ) do
    DeviceManagement.handle_body(ip_frame, body, ip_state)
  end

  defp handle_body(
         %IpFrame{service_family_id: service_family_id(:tunnelling)} = ip_frame,
         body,
         %IpState{} = ip_state
       ) do
    Tunnelling.handle_body(ip_frame, body, ip_state)
  end

  defp handle_body(
         %IpFrame{service_family_id: service_family_id(:routing)} = ip_frame,
         body,
         %IpState{} = ip_state
       ) do
    Routing.handle_body(ip_frame, body, ip_state)
  end

  defp handle_body(%IpFrame{}, _body, %IpState{} = ip_state) do
    warning(:invalid_service_familiy)
    {ip_state, []}
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

  def get_structure_length(structure_list) do
    Enum.reduce(structure_list, 0, fn structure, acc -> acc + structure_length(structure) end)
  end

  def convert_ip_to_number({e3, e2, e1, e0}) do
    (e3 <<< 24) + (e2 <<< 16) + (e1 <<< 8) + e0
  end

  def convert_number_to_ip(ip) do
    {ip >>> 24 &&& 0xFF, ip >>> 16 &&& 0xFF, ip >>> 8 &&& 0xFF, ip &&& 0xFF}
  end

  # ----------------------------------------------------------------------------

  defp get_service_family_id(service_type_id) do
    # service families have non-overlapping service type number ranges
    cond do
      service_type_id <= 0x0F -> service_family_id(:core)
      service_type_id <= 0x1F -> service_family_id(:device_management)
      service_type_id <= 0x2F -> service_family_id(:tunnelling)
      service_type_id <= 0x3F -> service_family_id(:routing)
    end
  end
end
