defmodule Knx.Knxnetip.Core do
  alias Knx.Knxnetip.IPFrame
  alias Knx.Knxnetip.ConTab
  alias Knx.Knxnetip.Endpoint, as: Ep
  alias Knx.Ail.Device

  require Knx.Defs
  import Knx.Defs

  @header_size 6
  @protocol_version 0x10
  @hpai_structure_length 8
  @dib_device_info_structure_length 0x36
  @dib_supp_svc_families_structure_length 8
  @universal_port 0x0E75

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
          control_hpai::size(@hpai_structure_length)-unit(8),
          data_hpai::size(@hpai_structure_length)-unit(8),
          cri::bits
        >>
      ) do
    control_endpoint =
      handle_hpai(<<control_hpai::size(@hpai_structure_length)-unit(8)>>)
      |> check_route_back_hpai(src)

    data_endpoint = handle_hpai(<<data_hpai::size(@hpai_structure_length)-unit(8)>>)

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
          0::8,
          control_hpai::size(@hpai_structure_length)-unit(8)
        >>
      ) do
    control_endpoint =
      handle_hpai(<<control_hpai::size(@hpai_structure_length)-unit(8)>>)
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
          0::8,
          control_hpai::size(@hpai_structure_length)-unit(8)
        >>
      ) do
    control_endpoint =
      handle_hpai(<<control_hpai::size(@hpai_structure_length)-unit(8)>>)
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
         @hpai_structure_length::8,
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
        <<tunneling_knx_layer::8, 0::8>> = connection_specific_info

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
        @header_size::8,
        @protocol_version::8,
        service_type_id(:search_resp)::16,
        @header_size + @hpai_structure_length + @dib_device_info_structure_length +
          @dib_supp_svc_families_structure_length::16
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
        @header_size::8,
        @protocol_version::8,
        service_type_id(:search_resp)::16,
        @header_size + @dib_device_info_structure_length +
          @dib_supp_svc_families_structure_length::16
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
        @header_size::8,
        @protocol_version::8,
        service_type_id(:connect_resp)::16,
        @header_size + 2 + @hpai_structure_length + crd_structure_length::16,
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
      @header_size::8,
      @protocol_version::8,
      service_type_id(:connectionstate_resp)::16,
      @header_size + 2::16,
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
      @header_size::8,
      @protocol_version::8,
      service_type_id(:disconnect_resp)::16,
      @header_size + 2::16,
      channel_id::8,
      disconnect_response_status_code(status)::8
    >>

    {:ethernet, :transmit, {dest, frame}}
  end

  defp hpai(host_protocol_code) do
    # TODO
    ip_addr = 0xC0A8_B23E

    <<
      @hpai_structure_length::8,
      host_protocol_code::8,
      ip_addr::32,
      @universal_port::16
    >>
  end

  defp dib_device_information() do
    props = Cache.get_obj(:device)
    device_status = Device.get_prog_mode(props)

    # TODO
    knx_medium = 0x00
    knx_individual_addr = 0x0000
    project_installation_id = 0x0000
    knx_serial_number = 0x000000000000
    routing_multicast_addr = 0x00000000
    mac_address = 0x000000000000
    friendly_name = 0x000000000000000000000000000000

    <<
      @dib_device_info_structure_length::8,
      description_type_code(:device_info)::8,
      # TODO where do we get this info from?
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
      @dib_supp_svc_families_structure_length::8,
      description_type_code(:supp_svc_families)::8,
      # all services: version 1
      0x02::8,
      0x01::8,
      0x03::8,
      0x01::8,
      0x04::8,
      0x01::8
    >>
  end

  defp crd(%IPFrame{con_type: con_type}) do
    # TODO
    knx_ind_addr = 0x0000

    case con_type do
      :device_mgmt_con ->
        <<2::8, connection_type_code(con_type)::8>>

      :tunnel_con ->
        <<4::8, connection_type_code(con_type), knx_ind_addr::16>>
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
