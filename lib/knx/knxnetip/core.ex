defmodule Knx.KnxnetIp.Core do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.KnxnetIpParameter, as: KnxnetIpParam
  alias Knx.Ail.Device

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  # ----------------------------------------------------------------------------
  # body handlers

  '''
  SEARCH REQUEST
  Description: 4.2
  Structure: 7.6.1
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:search_req)} = ip_frame,
        <<
          discovery_hpai::bytes-structure_length(:hpai)
        >>
      ) do
    # TODO How does this work if client frames pass routers with NAT?
    #  search_request is sent via multicast, i.e., src ip address from
    #  ip package cannot be used to replace HPAI (see 8.6.3.2). how can client know
    #  ip address to be written into hpai?
    discovery_endpoint = handle_hpai(discovery_hpai)

    ip_frame = %{ip_frame | discovery_endpoint: discovery_endpoint}

    [search_resp(ip_frame)]
  end

  '''
  DESCRIPTION REQUEST
  Description: 4.3
  Structure: 7.7.1
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:description_req)} = ip_frame,
        <<
          control_hpai::bytes-structure_length(:hpai)
        >>
      ) do
    control_endpoint = handle_hpai(control_hpai, ip_frame.ip_src_endpoint)

    ip_frame = %{ip_frame | control_endpoint: control_endpoint}

    [description_resp(ip_frame)]
  end

  '''
  CONNECT REQUEST
  Description: 5.2
  Structure: 7.8.1
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:connect_req)} = ip_frame,
        <<
          control_hpai::bytes-structure_length(:hpai),
          data_hpai::bytes-structure_length(:hpai),
          cri::bits
        >>
      ) do
    control_endpoint = handle_hpai(control_hpai, ip_frame.ip_src_endpoint)

    data_endpoint = handle_hpai(data_hpai, ip_frame.ip_src_endpoint)

    ip_frame = %{ip_frame | control_endpoint: control_endpoint, data_endpoint: data_endpoint}

    with {:ok, con_type} <- handle_cri(cri),
         {:ok, con_tab, channel_id} <- ConTab.open(Cache.get(:con_tab), con_type, ip_frame) do
      Cache.put(:con_tab, con_tab)

      ip_frame = %{
        ip_frame
        | status_code: connect_response_status_code(:no_error),
          channel_id: channel_id,
          con_type: con_type
      }

      # TODO set timer timeout (120s)
      [connect_resp(ip_frame), {:timer, :start, {:ip_connection, channel_id}}]
    else
      {:error, error_type} ->
        ip_frame = %{ip_frame | status_code: connect_response_status_code(error_type)}

        [connect_resp(ip_frame)]
    end
  end

  '''
  CONNECTIONSTATE REQUEST
  Description: 5.4
  Structure: 7.8.3
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:connectionstate_req)} = ip_frame,
        <<
          channel_id::8,
          knxnetip_constant(:reserved)::8,
          control_hpai::bytes-structure_length(:hpai)
        >>
      ) do
    control_endpoint = handle_hpai(control_hpai, ip_frame.ip_src_endpoint)

    ip_frame = %{
      ip_frame
      | control_endpoint: control_endpoint,
        channel_id: channel_id
    }

    # TODO if errors occur concerning the connection or knx subnetwork this could also
    #  be indicated here
    if ConTab.is_open?(Cache.get(:con_tab), channel_id) do
      ip_frame = %{ip_frame | status_code: connectionstate_response_status_code(:no_error)}

      [connectionstate_resp(ip_frame), {:timer, :restart, {:ip_connection, channel_id}}]
    else
      ip_frame = %{ip_frame | status_code: connectionstate_response_status_code(:connection_id)}

      [connectionstate_resp(ip_frame)]
    end
  end

  '''
  DISCONNECT REQUEST
  Description: 5.5
  Structure: 7.8.5
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:disconnect_req)} = ip_frame,
        <<
          channel_id::8,
          knxnetip_constant(:reserved)::8,
          control_hpai::bytes-structure_length(:hpai)
        >>
      ) do
    control_endpoint = handle_hpai(control_hpai, ip_frame.ip_src_endpoint)

    ip_frame = %{
      ip_frame
      | control_endpoint: control_endpoint,
        channel_id: channel_id
    }

    case ConTab.close(Cache.get(:con_tab), channel_id) do
      {:ok, con_tab} ->
        Cache.put(:con_tab, con_tab)
        ip_frame = %{ip_frame | status_code: common_error_code(:no_error)}
        [disconnect_resp(ip_frame), {:timer, :stop, {:ip_connection, ip_frame.channel_id}}]

      {:error, _error_reason} ->
        # !info: standard does not specify what to do if connection does not exist
        #  only says that invalid data packets shall be ignored (6.2)
        #  therefore: do nothing
        []
    end
  end

  def handle_body(_ip_frame, _src, _frame) do
    warning(:no_matching_handler)
    []
  end

  # ----------------------------------------------------------------------------
  # placeholder handlers

  '''
  HPAI
  Description: 3.2, 8.6.3
  Structure: 7.5.1
  '''

  defp handle_hpai(
         <<
           structure_length(:hpai)::8,
           protocol_code::8,
           ip_addr::32,
           port::16
         >>,
         ip_src_endpoint \\ nil
       ) do
    # [XXIX]
    if (ip_addr == 0 || port == 0) && ip_src_endpoint do
      ip_src_endpoint
    else
      %Ep{protocol_code: protocol_code, ip_addr: ip_addr, port: port}
    end
  end

  '''
  CRI (Connection Request Information)
  Core - Description/Structure: 7.5.2,
  Device Management - Structure: 4.2.3, Tunneling - Structure: 4.4.3
  '''

  defp handle_cri(<<
         _cri_structure_length::8,
         con_type_code(:tunnel_con),
         tunnelling_knx_layer_code(:tunnel_linklayer)::8,
         knxnetip_constant(:reserved)::8
       >>),
       do: {:ok, :tunnel_con}

  defp handle_cri(<<_cri_structure_length::8, con_type_code(:tunnel_con), _::bits>>),
    do: {:error, :connection_option}

  defp handle_cri(<<_cri_structure_length::8, con_type_code(:device_mgmt_con)>>),
    do: {:ok, :device_mgmt_con}

  defp handle_cri(_),
    do: {:error, :connection_type}

  # ----------------------------------------------------------------------------
  # impulse creators

  '''
  SEARCH RESPONSE
  Description: 4.2
  Structure: 7.6.2
  '''

  defp search_resp(%IpFrame{discovery_endpoint: discovery_endpoint}) do
    frame =
      Ip.header(
        service_type_id(:search_resp),
        Ip.get_structure_length([:header, :hpai, :dib_device_info, :dib_supp_svc_families])
      ) <>
        hpai(discovery_endpoint.protocol_code) <>
        dib_device_information() <>
        dib_supp_svc_families()

    {:ethernet, :transmit, {discovery_endpoint, frame}}
  end

  '''
  DESCRIPTION RESPONSE
  Description: 4.3
  Structure: 7.7.2
  '''

  defp description_resp(%IpFrame{control_endpoint: control_endpoint}) do
    frame =
      Ip.header(
        service_type_id(:description_resp),
        Ip.get_structure_length([:header, :dib_device_info, :dib_supp_svc_families])
      ) <>
        dib_device_information() <>
        dib_supp_svc_families()

    {:ethernet, :transmit, {control_endpoint, frame}}
  end

  '''
  CONNECT RESPONSE
  Description: 5.2
  Structure: 7.8.2
  '''

  defp connect_resp(
         %IpFrame{
           control_endpoint: control_endpoint,
           data_endpoint: data_endpoint,
           con_type: con_type,
           channel_id: channel_id,
           status_code: status_code
         } = ip_frame
       ) do
    frame =
      if status_code == common_error_code(:no_error) do
        Ip.header(
          service_type_id(:connect_resp),
          Ip.get_structure_length([:header, :connection_header_core, :hpai]) +
            crd_structure_length(con_type)
        ) <>
          connection_header(channel_id, status_code) <>
          hpai(data_endpoint.protocol_code) <>
          crd(ip_frame)
      else
        Ip.header(
          service_type_id(:connect_resp),
          structure_length(:header) + 1
        ) <>
          <<status_code::8>>
      end

    {:ethernet, :transmit, {control_endpoint, frame}}
  end

  '''
  CONNECTIONSTATE RESPONSE
  Description: 5.4
  Structure: 7.8.4
  '''

  defp connectionstate_resp(%IpFrame{
         control_endpoint: control_endpoint,
         channel_id: channel_id,
         status_code: status_code
       }) do
    frame =
      Ip.header(
        service_type_id(:connectionstate_resp),
        Ip.get_structure_length([:header, :connection_header_core])
      ) <>
        connection_header(channel_id, status_code)

    {:ethernet, :transmit, {control_endpoint, frame}}
  end

  '''
  DISCONNECT RESPONSE
  Description: 5.5
  Structure: 7.8.6
  '''

  defp disconnect_resp(%IpFrame{
         control_endpoint: control_endpoint,
         channel_id: channel_id,
         status_code: status_code
       }) do
    frame =
      Ip.header(
        service_type_id(:disconnect_resp),
        Ip.get_structure_length([:header, :connection_header_core])
      ) <>
        connection_header(channel_id, status_code)

    {:ethernet, :transmit, {control_endpoint, frame}}
  end

  '''
  DISCONNECT REQUEST
  Description: 5.5
  Structure: 7.8.5
  '''

  # TODO to be sent when timer of associated channel runs out
  # TODO handle possible error due to property read
  def disconnect_req(channel_id) do
    con_tab = Cache.get_obj(:con_tab)
    control_endpoint = ConTab.get_control_endpoint(con_tab, channel_id)
    data_endpoint = ConTab.get_data_endpoint(con_tab, channel_id)

    frame = <<
      channel_id::8,
      knxnetip_constant(:reserved)::8,
      hpai(data_endpoint.protocol_code)::structure_length(:hpai)*8
    >>

    {:ethernet, :transmit, {control_endpoint, frame}}
  end

  # ----------------------------------------------------------------------------
  # placeholder creators

  '''
  HPAI
  Description: 3.2, 8.6.2
  Structure: 7.5.1
  '''

  defp hpai(protocol_code) do
    # fyi: wir werden Cache von Agent in ETS aendern (erlang term storage)
    ip_addr = KnxnetIpParam.get_current_ip_addr(Cache.get_obj(:knxnet_ip_parameter))

    <<
      structure_length(:hpai)::8,
      protocol_code::8,
      ip_addr::32,
      knxnetip_constant(:port)::16
    >>
  end

  '''
  DIB Device Information
  Description/Structure: 7.5.4.2
  '''

  defp dib_device_information() do
    device_props = Cache.get_obj(:device)
    knxnet_ip_props = Cache.get_obj(:knxnet_ip_parameter)

    <<
      structure_length(:dib_device_info)::8,
      description_type_code(:device_info)::8,
      # TODO alternatively knx ip has to be set as knx_medium
      knx_medium_code(:tp1)::8,
      Device.get_prog_mode(device_props)::8,
      KnxnetIpParam.get_knx_indv_addr(knxnet_ip_props)::16,
      # TODO Project installation id; how is this supposed to be assigned? (core, 7.5.4.2) no associated property?
      0x0000::16,
      Device.get_serial(device_props)::48,
      KnxnetIpParam.get_routing_multicast_addr(knxnet_ip_props)::32,
      KnxnetIpParam.get_mac_addr(knxnet_ip_props)::48,
      KnxnetIpParam.get_friendly_name(knxnet_ip_props)::8*30
    >>
  end

  '''
  DIB Supported service families
  Description/Structure: 7.5.4.3
  '''

  defp dib_supp_svc_families() do
    <<
      structure_length(:dib_supp_svc_families)::8,
      description_type_code(:supp_svc_families)::8,
      service_family_id(:core)::8,
      protocol_version(:core)::8,
      service_family_id(:device_management)::8,
      protocol_version(:device_management)::8,
      service_family_id(:tunnelling)::8,
      protocol_version(:tunnelling)::8
    >>
  end

  '''
  CONNECTION HEADER
  Description/Structure: 5.3.1
  '''

  defp connection_header(channel_id, status_code) do
    <<
      channel_id::8,
      status_code::8
    >>
  end

  '''
  CRD (Connection Response Data Block)
  Core - Description/Structure: 7.5.3,
  Device Management - Structure: 4.2.4, Tunneling - Structure: 4.4.4
  '''

  defp crd(%IpFrame{con_type: con_type}) do
    props = Cache.get_obj(:knxnet_ip_parameter)

    case con_type_code(con_type) do
      con_type_code(:device_mgmt_con) ->
        <<structure_length(:crd_device_mgmt_con)::8, con_type_code(con_type)::8>>

      con_type_code(:tunnel_con) ->
        <<structure_length(:crd_tunnel_con)::8, con_type_code(con_type),
          KnxnetIpParam.get_knx_indv_addr(props)::16>>
    end
  end
end
