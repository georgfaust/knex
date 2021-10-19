defmodule Knx.KnxnetIp.Core do
  alias Knx.KnxnetIp.Knip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.Parameter, as: KnipParameter
  alias Knx.Ail.Device
  alias Knx.State.KnxnetIp, as: IpState

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  @moduledoc """
  The Core module handles the body of KNXnet/IP-frames of the identically named service family.

  As a result, the updated ip_state and a list of impulses/effects are returned.
  Impulses include the respective response frames.
  """

  # ----------------------------------------------------------------------------
  # body handlers

  @doc """
  Handles body of KNXnet/IP frames.

  For every service type, there is one function clause.

  ## KNX specification

  For further information on the request services, refer to the
  following sections in document 03_08_02 (KNXnet/IP Core):

  ```
  +-------------------------+-------------+-----------+
  |      Service Type       | Description | Structure |
  +-------------------------+-------------+-----------+
  | Search Request          |         4.2 |     7.6.1 |
  | Description Request     |         4.3 |     7.7.1 |
  | Connect Request         |         5.2 |     7.8.1 |
  | Connectionstate Request |         5.4 |     7.8.3 |
  | Disconnect Request      |         5.5 |     7.8.5 |
  +-------------------------+-------------+-----------+
  ```
  """
  def handle_body(
        %IpFrame{service_type_id: service_type_id(:search_req)} = ip_frame,
        <<
          discovery_hpai::bytes-structure_length(:hpai)
        >>,
        %IpState{} = ip_state
      ) do
    discovery_endpoint = handle_hpai(discovery_hpai)

    ip_frame = %{ip_frame | discovery_endpoint: discovery_endpoint}

    {ip_state, [search_resp(ip_frame)]}
  end

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:description_req)} = ip_frame,
        <<
          control_hpai::bytes-structure_length(:hpai)
        >>,
        %IpState{} = ip_state
      ) do
    control_endpoint = handle_hpai(control_hpai, ip_frame.ip_src_endpoint)

    ip_frame = %{ip_frame | control_endpoint: control_endpoint}

    {ip_state, [description_resp(ip_frame)]}
  end

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:connect_req)} = ip_frame,
        <<
          control_hpai::bytes-structure_length(:hpai),
          data_hpai::bytes-structure_length(:hpai),
          cri::bits
        >>,
        %IpState{con_tab: con_tab} = ip_state
      ) do
    control_endpoint = handle_hpai(control_hpai, ip_frame.ip_src_endpoint)
    data_endpoint = handle_hpai(data_hpai, ip_frame.ip_src_endpoint)
    con_knx_indv_addr = KnipParameter.get_knx_indv_addr(Cache.get_obj(:knxnet_ip_parameter))

    ip_frame = %{
      ip_frame
      | control_endpoint: control_endpoint,
        data_endpoint: data_endpoint,
        con_knx_indv_addr: con_knx_indv_addr
    }

    with {:ok, con_type} <- handle_cri(cri),
         {:ok, con_tab, channel_id} <- ConTab.open(con_tab, con_type, ip_frame) do
      ip_frame = %{
        ip_frame
        | status_code: connect_response_status_code(:no_error),
          channel_id: channel_id,
          con_type: con_type
      }

      # TODO set timer timeout (120s)
      {%{ip_state | con_tab: con_tab},
       [connect_resp(ip_frame), {:timer, :start, {:ip_connection, channel_id}}]}
    else
      {:error, error_type} ->
        ip_frame = %{ip_frame | status_code: connect_response_status_code(error_type)}

        {ip_state, [connect_resp(ip_frame)]}
    end
  end

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:connectionstate_req)} = ip_frame,
        <<
          channel_id::8,
          knxnetip_constant(:reserved)::8,
          control_hpai::bytes-structure_length(:hpai)
        >>,
        %IpState{con_tab: con_tab} = ip_state
      ) do
    control_endpoint = handle_hpai(control_hpai, ip_frame.ip_src_endpoint)

    ip_frame = %{
      ip_frame
      | control_endpoint: control_endpoint,
        channel_id: channel_id
    }

    if ConTab.is_open?(con_tab, channel_id) do
      ip_frame = %{ip_frame | status_code: connectionstate_response_status_code(:no_error)}

      {ip_state,
       [connectionstate_resp(ip_frame), {:timer, :restart, {:ip_connection, channel_id}}]}
    else
      ip_frame = %{ip_frame | status_code: connectionstate_response_status_code(:connection_id)}

      {ip_state, [connectionstate_resp(ip_frame)]}
    end
  end

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:disconnect_req)} = ip_frame,
        <<
          channel_id::8,
          knxnetip_constant(:reserved)::8,
          control_hpai::bytes-structure_length(:hpai)
        >>,
        %IpState{con_tab: con_tab} = ip_state
      ) do
    control_endpoint = handle_hpai(control_hpai, ip_frame.ip_src_endpoint)

    ip_frame = %{
      ip_frame
      | control_endpoint: control_endpoint,
        channel_id: channel_id
    }

    case ConTab.close(con_tab, channel_id) do
      {:ok, con_tab} ->
        ip_frame = %{ip_frame | status_code: common_error_code(:no_error)}

        {%{ip_state | con_tab: con_tab},
         [disconnect_resp(ip_frame), {:timer, :stop, {:ip_connection, ip_frame.channel_id}}]}

      {:error, _error_reason} ->
        {ip_state, []}
    end
  end

  def handle_body(_ip_frame, _frame, %IpState{} = ip_state) do
    warning(:no_matching_handler)
    {ip_state, []}
  end

  # ----------------------------------------------------------------------------
  # placeholder handlers

  ### [private doc]
  # Handles HPAI (Host Protocol Address Information).
  #
  # The HPAI of an endpoint describes its properties: ip address, port number and
  # protocol (either UDP or TCP).
  #
  # IP address or port equal to 0 indicate that telegrams traverse across routers
  # using NAT. In this case, replace by IP address and port from IP package.
  #
  # KNX specification:
  #   Document 03_08_02, sections 3.2, 8.6.3 (description) & 7.5.1 (structure)
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
      %Ep{protocol_code: protocol_code, ip_addr: Knip.convert_number_to_ip(ip_addr), port: port}
    end
  end

  ### [private doc]
  # Handles CRI (Connection Request Information).
  #
  # Tells server whether clients requests device management or tunnelling connection.
  #
  # Server may support different knx layers for tunnelling connection. However,
  # here, only tunnelling linklayer connections are supported.
  #
  # KNX specification:
  #   Document 03_08_02, section 7.5.2 (description)
  #   Document 03_08_03, section 4.2.3 (structure device management)
  #   Document 03_08_04, section 4.4.3 (structure tunnelling)
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

  ### [private doc]
  # Produces impulse for SEARCH_RESPONSE frame.
  #
  # KNX specification:
  #   Document 03_08_02, sections 4.2 (description) & 7.6.2 (structure)
  defp search_resp(%IpFrame{discovery_endpoint: discovery_endpoint}) do
    dib_supp_svc_families = dib_supp_svc_families()

    total_length =
      Knip.get_structure_length([:header, :hpai, :dib_device_info]) +
        byte_size(dib_supp_svc_families)

    header = Knip.header(service_type_id(:search_resp), total_length)

    body =
      hpai(discovery_endpoint.protocol_code) <>
        dib_device_information() <> dib_supp_svc_families

    {:ip, :transmit, {discovery_endpoint, header <> body}}
  end

  ### [private doc]
  # Produces impulse for DESCRIPTION_RESPONSE frame.
  #
  # KNX specification:
  #   Document 03_08_02, sections 4.3 (description) & 7.7.2 (structure)
  defp description_resp(%IpFrame{control_endpoint: control_endpoint}) do
    dib_supp_svc_families = dib_supp_svc_families()

    total_length =
      Knip.get_structure_length([:header, :dib_device_info]) +
        byte_size(dib_supp_svc_families)

    header = Knip.header(service_type_id(:description_resp), total_length)
    body = dib_device_information() <> dib_supp_svc_families

    {:ip, :transmit, {control_endpoint, header <> body}}
  end

  ### [private doc]
  # Produces impulse for CONNECT_RESPONSE frame.
  #
  # KNX specification:
  #   Document 03_08_02, sections 5.2 (description) & 7.8.2 (structure)
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
        total_length =
          Knip.get_structure_length([:header, :connection_header_core, :hpai]) +
            crd_structure_length(con_type)

        header = Knip.header(service_type_id(:connect_resp), total_length)

        body =
          connection_header(channel_id, status_code) <>
            hpai(data_endpoint.protocol_code) <>
            crd(ip_frame)

        header <> body
      else
        header = Knip.header(service_type_id(:connect_resp), structure_length(:header) + 1)
        # TODO wireshark says a byte is missing here: pseudo connection id?
        body = <<status_code::8>>
        header <> body
      end

    {:ip, :transmit, {control_endpoint, frame}}
  end

  ### [private doc]
  # Produces impulse for CONNECTIONSTATE_RESPONSE frame.
  #
  # KNX specification:
  #   Document 03_08_02, sections 5.4 (description) & 7.8.4 (structure)
  defp connectionstate_resp(%IpFrame{
         control_endpoint: control_endpoint,
         channel_id: channel_id,
         status_code: status_code
       }) do
    total_length = Knip.get_structure_length([:header, :connection_header_core])
    header = Knip.header(service_type_id(:connectionstate_resp), total_length)
    body = connection_header(channel_id, status_code)

    {:ip, :transmit, {control_endpoint, header <> body}}
  end

  ### [private doc]
  # Produces impulse for DISCONNECT_RESPONSE frame.
  #
  # KNX specification:
  #   Document 03_08_02, sections 5.5 (description) & 7.8.6 (structure)
  defp disconnect_resp(%IpFrame{
         control_endpoint: control_endpoint,
         channel_id: channel_id,
         status_code: status_code
       }) do
    total_length = Knip.get_structure_length([:header, :connection_header_core])
    header = Knip.header(service_type_id(:disconnect_resp), total_length)
    body = connection_header(channel_id, status_code)

    {:ip, :transmit, {control_endpoint, header <> body}}
  end

  @doc """
  Produces impulse for DISCONNECT_REQUEST frame.

  Is sent when the connection timer runs out.

  KNX specification:
    Document 03_08_02, sections 5.5 (description) & 7.8.6 (structure)
  """
  def disconnect_req(channel_id, con_tab) do
    control_endpoint = ConTab.get_control_endpoint(con_tab, channel_id)
    data_endpoint = ConTab.get_data_endpoint(con_tab, channel_id)

    total_length = Knip.get_structure_length([:header, :connection_header_core, :hpai])
    header = Knip.header(service_type_id(:disconnect_req), total_length)

    body =
      <<
        channel_id::8,
        knxnetip_constant(:reserved)::8
      >> <>
        hpai(data_endpoint.protocol_code)

    {:ip, :transmit, {control_endpoint, header <> body}}
  end

  # ----------------------------------------------------------------------------
  # placeholder creators

  ### [private doc]
  # Produces HPAI (Host Protocol Address Information).
  #
  # The HPAI of an endpoint describes its properties: ip address, port number and
  # protocol (either UDP or TCP).
  #
  # KNX specification:
  #   Document 03_08_02, sections 3.2, 8.6.2 (description) & 7.5.1 (structure)
  defp hpai(protocol_code) do
    ip_addr = KnipParameter.get_current_ip_addr(Cache.get_obj(:knxnet_ip_parameter))

    <<
      structure_length(:hpai)::8,
      protocol_code::8,
      ip_addr::32,
      knxnetip_constant(:port)::16
    >>
  end

  ### [private doc]
  # Produces DIB (Description Information Block) of type Device Information.
  #
  # Field 'project installation id' is not specified.
  #
  # KNX specification:
  #   Document 03_08_02, section 7.5.4.2 (description/structure)
  defp dib_device_information() do
    device_props = Cache.get_obj(:device)
    knxnet_ip_props = Cache.get_obj(:knxnet_ip_parameter)
    knx_medium = Application.get_env(:knx, :knx_medium, :tp1)

    <<
      structure_length(:dib_device_info)::8,
      description_type_code(:device_info)::8,
      knx_medium_code(knx_medium)::8,
      Device.get_prog_mode(device_props)::8,
      KnipParameter.get_knx_indv_addr(knxnet_ip_props)::16,
      # Project installation id
      0x0000::16,
      Device.get_serial(device_props)::48,
      KnipParameter.get_routing_multicast_addr(knxnet_ip_props)::32,
      KnipParameter.get_mac_addr(knxnet_ip_props)::48,
      KnipParameter.get_friendly_name(knxnet_ip_props)::8*30
    >>
  end

  ### [private doc]
  # Produces DIB (Description Information Block) of type Supported Service Families.
  #
  # KNX specification:
  #   Document 03_08_02, section 7.5.4.3 (description/structure)
  defp dib_supp_svc_families() do
    knx_device_type = Application.get_env(:knx, :knx_device_type, :knx_ip_interface)

    {structure_length, tail} =
      case knx_device_type do
        :knx_ip_interface ->
          {8, <<service_family_id(:tunnelling)::8, protocol_version(:tunnelling)::8>>}

        :knx_ip ->
          {6, <<>>}

        _ ->
          :logger.warning(
            ":knx_device_type should be either set to 'knx_ip_interface' or 'knx_ip'. (see config.exs in app)"
          )

          {6, <<>>}
      end

    <<
      structure_length::8,
      description_type_code(:supp_svc_families)::8,
      service_family_id(:core)::8,
      protocol_version(:core)::8,
      service_family_id(:device_management)::8,
      protocol_version(:device_management)::8
    >> <> tail
  end

  ### [private doc]
  # Produces Connection Header.
  #
  # KNX specification:
  #   Document 03_08_02, section 5.3.1 (description/structure)
  defp connection_header(channel_id, status_code) do
    <<
      channel_id::8,
      status_code::8
    >>
  end

  ### [private doc]
  # Produces CRD (Connection Response Data Block).
  #
  # KNX specification:
  #   Document 03_08_02, section 7.5.3 (description/structure)
  #   Document 03_08_03, section 4.2.4 (structure)
  #   Document 03_08_04, section 4.4.4 (structure)
  defp crd(%IpFrame{con_type: con_type, con_knx_indv_addr: con_knx_indv_addr}) do
    case con_type_code(con_type) do
      con_type_code(:device_mgmt_con) ->
        <<structure_length(:crd_device_mgmt_con)::8, con_type_code(con_type)::8>>

      con_type_code(:tunnel_con) ->
        <<structure_length(:crd_tunnel_con)::8, con_type_code(con_type), con_knx_indv_addr::16>>
    end
  end
end
