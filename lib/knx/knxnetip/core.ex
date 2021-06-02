defmodule Knx.Knxnetip.Core do
  alias Knx.Knxnetip.IPFrame
  alias Knx.Knxnetip.ConTab
  alias Knx.Knxnetip.Endpoint, as: Ep
  alias Knx.Ail.Device
  alias Knx.Ail.Property, as: P

  require Knx.Defs
  import Knx.Defs

  def handle_body(
        src,
        %IPFrame{service_type_id: service_type_id(:search_req)} = ip_frame,
        <<
          control_hpai::bits
        >>
      ) do
    control_endpoint = handle_hpai(control_hpai) |> check_route_back_hpai(src)

    ip_frame = %{ip_frame | control_endpoint: control_endpoint}

    [search_resp(ip_frame)]
  end

  def handle_body(
        src,
        %IPFrame{service_type_id: service_type_id(:description_req)} = ip_frame,
        <<
          control_hpai::bits
        >>
      ) do
    control_endpoint = handle_hpai(control_hpai) |> check_route_back_hpai(src)

    ip_frame = %{ip_frame | control_endpoint: control_endpoint}

    [description_resp(ip_frame)]
  end

  def handle_body(
        src,
        %IPFrame{service_type_id: service_type_id(:connect_req)} = ip_frame,
        <<
          control_hpai::size(structure_length(:hpai))-unit(8),
          data_hpai::size(structure_length(:hpai))-unit(8),
          cri::bits
        >>
      ) do
    control_endpoint =
      handle_hpai(<<control_hpai::size(structure_length(:hpai))-unit(8)>>)
      |> check_route_back_hpai(src)

    data_endpoint = handle_hpai(<<data_hpai::size(structure_length(:hpai))-unit(8)>>)

    ip_frame = %{ip_frame | control_endpoint: control_endpoint, data_endpoint: data_endpoint}

    ip_frame =
      case handle_cri(cri) do
        {:error, error_type} ->
          %{ip_frame | status: error_type}

        {:tunnel_con, {knx_layer}} ->
          %{ip_frame | con_type: :tunnel_con, knx_layer: knx_layer}

        {:device_mgmt_con, _} ->
          %{ip_frame | con_type: :device_mgmt_con}
      end

    con_tab = Cache.get(:con_tab)
    {con_tab, result} = ConTab.open(con_tab, ip_frame.con_type, data_endpoint)
    Cache.put(:con_tab, con_tab)

    ip_frame =
      case result do
        {:error, :no_more_connections} ->
          if ip_frame.status == :no_error, do: %{ip_frame | status: :no_more_connections}

        channel_id ->
          %{ip_frame | channel_id: channel_id}
      end

    [connect_resp(ip_frame)]
  end

  def handle_body(
        src,
        %IPFrame{service_type_id: service_type_id(:connectionstate_req)} = ip_frame,
        <<
          channel_id::8,
          knxnetip_constant(:reserved)::8,
          control_hpai::size(structure_length(:hpai))-unit(8)
        >>
      ) do
    control_endpoint =
      handle_hpai(<<control_hpai::size(structure_length(:hpai))-unit(8)>>)
      |> check_route_back_hpai(src)

    con_tab = Cache.get(:con_tab)
    status = if ConTab.is_open?(con_tab, channel_id), do: :no_error, else: :connection_id

    ip_frame = %{
      ip_frame
      | control_endpoint: control_endpoint,
        channel_id: channel_id,
        status: status
    }

    [connectionstate_resp(ip_frame)]
  end

  def handle_body(
        src,
        %IPFrame{service_type_id: service_type_id(:disconnect_req)} = ip_frame,
        <<
          channel_id::8,
          knxnetip_constant(:reserved)::8,
          control_hpai::size(structure_length(:hpai))-unit(8)
        >>
      ) do
    control_endpoint =
      handle_hpai(<<control_hpai::size(structure_length(:hpai))-unit(8)>>)
      |> check_route_back_hpai(src)

    ip_frame = %{
      ip_frame
      | control_endpoint: control_endpoint,
        channel_id: channel_id
    }

    con_tab = Cache.get(:con_tab)
    {con_tab, result} = ConTab.close(con_tab, channel_id)
    Cache.put(:con_tab, con_tab)

    ip_frame =
      case result do
        # TODO is this correct? (not specified)
        {:error, :connection_id} ->
          %{ip_frame | status: :connection_id}

        _id ->
          ip_frame
      end

    [disconnect_resp(ip_frame)]
  end

  # ----------------------------------------------------------------------------

  defp handle_hpai(<<
         structure_length(:hpai)::8,
         protocol_code::8,
         ip_addr::32,
         port::16
       >>) do
    %Ep{protocol_code: protocol_code, ip_addr: ip_addr, port: port}
  end

  defp handle_cri(
         <<_cri_structure_length::8, connection_type_code::8, connection_specific_info::bits>>
       ) do
    case connection_type_code do
      connection_type_code(:tunnel_con) ->
        <<tunneling_knx_layer::8, knxnetip_constant(:reserved)::8>> = connection_specific_info

        case tunneling_knx_layer do
          tunneling_knx_layer(:tunnel_linklayer) -> {:tunnel_con, {tunneling_knx_layer}}
          _ -> {:error, :connection_option}
        end

      connection_type_code(:device_mgmt_con) ->
        {:device_mgmt_con, {}}

      _ ->
        {:error, :connection_type}
    end
  end

  defp search_resp(%IPFrame{control_endpoint: dest}) do
    frame =
      <<
        structure_length(:header)::8,
        protocol_version(:knxnetip)::8,
        service_type_id(:search_resp)::16,
        structure_length(:header) + structure_length(:hpai) + structure_length(:dib_device_info) +
          structure_length(:dib_supp_svc_families)::16
      >> <>
        hpai(dest.protocol_code) <>
        dib_device_information() <>
        dib_supp_svc_families()

    {:ethernet, :transmit, {dest, frame}}
  end

  defp description_resp(%IPFrame{
         control_endpoint: dest
       }) do
    frame =
      <<
        structure_length(:header)::8,
        protocol_version(:knxnetip)::8,
        service_type_id(:search_resp)::16,
        structure_length(:header) + structure_length(:dib_device_info) +
          structure_length(:dib_supp_svc_families)::16
      >> <>
        dib_device_information() <>
        dib_supp_svc_families()

    {:ethernet, :transmit, {dest, frame}}
  end

  defp connect_resp(
         %IPFrame{
           control_endpoint: dest,
           data_endpoint: data_endpoint,
           con_type: con_type,
           channel_id: channel_id,
           status: status
         } = ip_frame
       ) do
    crd_structure_length = if con_type == :device_mgmt_con, do: 2, else: 4

    frame =
      <<
        structure_length(:header)::8,
        protocol_version(:knxnetip)::8,
        service_type_id(:connect_resp)::16,
        structure_length(:header) + 2 + structure_length(:hpai) + crd_structure_length::16,
        channel_id::8,
        connect_response_status_code(status)::8
      >> <>
        hpai(data_endpoint.protocol_code) <>
        crd(ip_frame)

    {:ethernet, :transmit, {dest, frame}}
  end

  defp connectionstate_resp(%IPFrame{
         control_endpoint: dest,
         channel_id: channel_id,
         status: status
       }) do
    frame = <<
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_type_id(:connectionstate_resp)::16,
      structure_length(:header) + 2::16,
      channel_id::8,
      connectionstate_response_status_code(status)::8
    >>

    {:ethernet, :transmit, {dest, frame}}
  end

  defp disconnect_resp(%IPFrame{
         control_endpoint: dest,
         channel_id: channel_id,
         status: status
       }) do
    frame = <<
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_type_id(:disconnect_resp)::16,
      structure_length(:header) + 2::16,
      channel_id::8,
      disconnect_response_status_code(status)::8
    >>

    {:ethernet, :transmit, {dest, frame}}
  end

  defp hpai(host_protocol_code) do
    props = Cache.get_obj(:knxnet_ip_parameter)
    ip_addr = P.read_prop_value(props, :current_ip_address)

    <<
      structure_length(:hpai)::8,
      host_protocol_code::8,
      ip_addr::32,
      knxnetip_constant(:port)::16
    >>
  end

  defp dib_device_information() do
    device_props = Cache.get_obj(:device)
    knxnet_ip_props = Cache.get_obj(:knxnet_ip_parameter)

    knx_medium = knx_medium_code(:tp1)
    device_status = Device.get_prog_mode(device_props)
    knx_individual_addr = P.read_prop_value(knxnet_ip_props, :knx_individual_address)
    # TODO how is this supposed to be assigned? (core, 7.5.4.2)
    project_installation_id = 0x0000
    knx_serial_number = P.read_prop_value(device_props, :serial)
    routing_multicast_addr = P.read_prop_value(knxnet_ip_props, :routing_multicast_address)
    mac_address = P.read_prop_value(knxnet_ip_props, :mac_address)
    friendly_name = P.read_prop_value(knxnet_ip_props, :friendly_name)

    <<
      structure_length(:dib_device_info)::8,
      description_type_code(:device_info)::8,
      knx_medium::8,
      device_status::8,
      knx_individual_addr::16,
      project_installation_id::16,
      knx_serial_number::48,
      routing_multicast_addr::32,
      mac_address::48,
      friendly_name::unit(8)-size(30)
    >>
  end

  defp dib_supp_svc_families() do
    <<
      structure_length(:dib_supp_svc_families)::8,
      description_type_code(:supp_svc_families)::8,
      service_family_id(:core)::8,
      protocol_version(:core)::8,
      service_family_id(:device_management)::8,
      protocol_version(:device_management)::8,
      service_family_id(:tunneling)::8,
      protocol_version(:tunneling)::8
    >>
  end

  defp crd(%IPFrame{con_type: con_type}) do
    props = Cache.get_obj(:knxnet_ip_parameter)
    knx_individual_addr = P.read_prop_value(props, :knx_individual_address)

    case con_type do
      :device_mgmt_con ->
        <<2::8, connection_type_code(con_type)::8>>

      :tunnel_con ->
        <<4::8, connection_type_code(con_type), knx_individual_addr::16>>
    end
  end

  # ----------------------------------------------------------------------------

  # [XXIX]
  defp check_route_back_hpai(
         %Ep{ip_addr: ip_addr, port: port} = endpoint,
         src
       ) do
    if ip_addr == 0 && port == 0 do
      src
    else
      endpoint
    end
  end
end
