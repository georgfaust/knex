defmodule Knx.KnxnetIp.Knip do
  alias Knx.KnxnetIp.Core
  alias Knx.KnxnetIp.DeviceManagement
  alias Knx.KnxnetIp.Tunnelling
  alias Knx.KnxnetIp.Routing
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.Parameter, as: KnipParameter
  alias Knx.State, as: S
  alias Knx.State.KnxnetIp, as: IpState

  import PureLogger
  require Knx.Defs
  import Knx.Defs
  use Bitwise

  @moduledoc """
  The Knip module acts as the interface for handling of KNXnet/IP frames.
  This is also true for knx frames when a tunnelling connection is open.
  """

  @doc """
  Handles KNXnet/IP frames and knx frames (when a tunnelling connection is open).

  KNXnet/IP frames:
    1. the header of the frame is handled.
    2. the validity of the length field is checked.
    3. the existence of the connection is checked (only for Device Management and Tunnelling frames).
    4. handle_body of the respective module is called.

  KNX frames:
    1. the existence of the connection is checked.
    2. handle_up_frame of the Tunnelling module is called.
  """
  def handle(
        {:knip, :from_ip,
         {ip_src_endpoint, <<header::bytes-structure_length(:header), body::bits>> = frame}},
        %S{knxnetip: ip_state} = state
      ) do
    ip_frame = %IpFrame{ip_src_endpoint: ip_src_endpoint}

    with {:ok, ip_frame} <- handle_header(ip_frame, header),
         :ok <- check_length(ip_frame, body),
         :ok <- check_connection(ip_frame, body, ip_state),
         {ip_state, impulses} <- handle_body(ip_frame, body, ip_state) do
      {%{state | knxnetip: ip_state}, impulses}
    else
      {:error, error_reason} ->
        :logger.warning("[D: #{Process.get(:cache_id)}] #{error_reason}: #{frame}")
        {state, []}
    end
  end

  def handle({:knip, :from_knx, data_cemi_frame}, %S{knxnetip: ip_state} = state) do
    with :ok <- check_connection(ip_state) do
      {ip_state, impulses} = Tunnelling.handle_up_frame(data_cemi_frame, ip_state)
      {%{state | knxnetip: ip_state}, impulses}
    else
      :no_tunnelling_connection ->
        {state, []}
    end
  end

  # ----------------------------------------------------------------------------

  ### [private doc]
  # Handles the header of any KNXnet/IP frame.
  #
  # A data packet with an unsupported version field or wrong structure length
  # is not accepted.
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
    ip_frame = %IpFrame{
      ip_frame
      | service_family_id: service_family_id,
        service_type_id: service_type_id,
        total_length: total_length
    }

    {:ok, ip_frame}
  end

  defp handle_header(_ip_frame, _frame) do
    {:error, :invalid_header}
  end

  # ----------------------------------------------------------------------------

  ### [private doc]
  # Checks if total length field is equal to actual length of frame.
  #
  # Also fails for empty body.
  defp check_length(%IpFrame{total_length: total_length}, body) do
    cond do
      total_length != structure_length(:header) + byte_size(body) ->
        {:error, :invalid_total_length}

      byte_size(body) == 0 ->
        {:error, :empty_body}

      true ->
        :ok
    end
  end

  ### [private doc]
  # Checks if connection actually exists (only for device management and tunnelling).
  defp check_connection(%IpState{con_tab: con_tab}) do
    props = Cache.get_obj(:knxnet_ip_parameter)

    if Map.has_key?(con_tab[:tunnel_cons], KnipParameter.get_knx_indv_addr(props)) do
      :ok
    else
      :no_tunnelling_connection
    end
  end

  defp check_connection(
         %IpFrame{service_family_id: service_family_id(:device_management)},
         body,
         %IpState{con_tab: con_tab}
       ) do
    channel_id = extract_channel_id(body)
    if ConTab.is_open?(con_tab, channel_id), do: :ok, else: {:error, :no_connection}
  end

  defp check_connection(
         %IpFrame{service_family_id: service_family_id(:tunnelling)},
         body,
         %IpState{con_tab: con_tab}
       ) do
    channel_id = extract_channel_id(body)
    if ConTab.is_open?(con_tab, channel_id), do: :ok, else: {:error, :no_connection}
  end

  defp check_connection(%IpFrame{}, _body, %IpState{}) do
    :ok
  end

  # ----------------------------------------------------------------------------

  ### [private doc]
  # Calls handle_body of respective module.
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

  @doc """
  Produces header of KNXnet/IP frame.
  """
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

  @doc """
  Returns structure length of atom list 'structure_list'.

  Atoms must be included in structure_length enum of defs.ex.
  """
  def get_structure_length(structure_list) do
    Enum.reduce(structure_list, 0, fn structure, acc -> acc + structure_length(structure) end)
  end

  @doc """
  Converts IP address 4-tuple to number.
  """
  def convert_ip_to_number({e3, e2, e1, e0}) do
    (e3 <<< 24) + (e2 <<< 16) + (e1 <<< 8) + e0
  end

  @doc """
  Converts IP address number to 4-tuple.
  """
  def convert_number_to_ip(ip) do
    {ip >>> 24 &&& 0xFF, ip >>> 16 &&& 0xFF, ip >>> 8 &&& 0xFF, ip &&& 0xFF}
  end

  # ----------------------------------------------------------------------------

  ### [private doc]
  # Determines service family id from service type id.
  defp get_service_family_id(service_type_id) do
    # service families have non-overlapping service type number ranges
    cond do
      service_type_id <= 0x0F -> service_family_id(:core)
      service_type_id <= 0x1F -> service_family_id(:device_management)
      service_type_id <= 0x2F -> service_family_id(:tunnelling)
      service_type_id <= 0x3F -> service_family_id(:routing)
    end
  end

  ### [private doc]
  # Returns channel id from KNXnet/IP frame body (that has connection header).
  defp extract_channel_id(<<_connection_header_length::8, channel_id::8, _tail::bits>>) do
    channel_id
  end
end
