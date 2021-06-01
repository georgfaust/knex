defmodule Knx.Knxnetip.IpInterface do
  alias Knx.Knxnetip.IPFrame
  alias Knx.Knxnetip.CEMIFrame
  alias Knx.Knxnetip.MgmtCEMIFrame
  alias Knx.Knxnetip.ConTab
  alias Knx.Knxnetip.Endpoint, as: Ep
  alias Knx.State, as: S
  alias Knx.Ail.Property, as: P
  alias Knx.Ail.Device

  require Knx.Defs
  import Knx.Defs

  @header_size 6
  @protocol_version 0x10
  @hpai_structure_length 8
  @dib_device_info_structure_length 0x36
  @dib_supp_svc_families_structure_length 8
  @universal_port 0x0E75

  # TODO
  ## - implement heartbeat monitoring
  ## - implement endpoint struct
  ## - defend additional individual addresses (tunneling, 2.2.2)
  ## - generate Layer-2 ack frames for additional individual addresses (tunneling, 2.2.2)

  # Open questions
  ## How does the server deal with ACKs?

  def handle({:ip, :from_ip, src, data}, %S{}) do
    # Core
    ## SEARCH_REQUEST -> SEARCH_RESPONSE
    ## DESCRIPTION_REQUEST -> DESCRIPTION_RESPONSE
    ## CONNECT_REQUEST -> CONNECT_RESPONSE
    ## CONNECTSTATE_REQUEST -> CONNECTSTATE_RESPONSE
    ## DISCONNECT_REQUEST -> DISCONNECT_RESPONSE
    ### [{:ethernet, :transmit, ip_frame}]

    # Device Management
    ## DEVICE_CONFIGURATION_REQUEST (.req) -> DEVICE_CONFIGURATION_ACK, DEVICE_CONFIGURATION_REQUEST (.con)
    ### [{:ethernet, :transmit, ip_frame1}, {:ethernet, :transmit, ip_frame2}]
    ## DEVICE_CONFIGURATION_ACK
    ### increment sequence counter

    # Tunneling
    ## TUNNELING_REQUEST -> TUNNELING_ACK, tp_frame
    ### [{:ethernet, :transmit, ip_frame}, {:dl, :req, %CEMIFrame{}}]

    handle_(src, data)

    ## TUNNELING_ACK
    ### increment sequence counter
  end

  # ----------------------------------------

  defp handle_(src, data) do
    {ip_frame, body} = handle_header(data)
    handle_body(src, ip_frame, body)
  end

  # header always has same structure
  defp handle_header(<<
         @header_size::8,
         @protocol_version::8,
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

  defp handle_body(
         src,
         %IPFrame{service_type_id: service_type_id(:search_req)} = ip_frame,
         <<
           discovery_endpoint::bits
         >>
       ) do
    {control_host_protocol_code, ip_addr, port} = handle_hpai(discovery_endpoint)

    {ip_addr, port} =
      (fn ->
         if ip_addr == 0 && port == 0, do: src, else: {ip_addr, port}
       end).()

    ip_frame = %{
      ip_frame
      | control_host_protocol_code: control_host_protocol_code,
        control_endpoint: {ip_addr, port}
    }

    [search_resp(ip_frame)]
  end

  defp handle_body(
         src,
         %IPFrame{service_type_id: service_type_id(:description_req)} = ip_frame,
         <<
           discovery_endpoint::bits
         >>
       ) do
    {control_host_protocol_code, ip_addr, port} = handle_hpai(discovery_endpoint)

    {ip_addr, port} = if ip_addr == 0 && port == 0, do: src, else: {ip_addr, port}

    ip_frame = %{
      ip_frame
      | control_host_protocol_code: control_host_protocol_code,
        control_endpoint: {ip_addr, port}
    }

    [description_resp(ip_frame)]
  end

  defp handle_body(
         src,
         %IPFrame{service_type_id: service_type_id(:connect_req)} = ip_frame,
         <<
           control_endpoint::size(@hpai_structure_length)-unit(8),
           data_endpoint::size(@hpai_structure_length)-unit(8),
           cri::bits
         >>
       ) do
    {control_host_protocol_code, control_ip_addr, control_port} =
      handle_hpai(<<control_endpoint::size(@hpai_structure_length)-unit(8)>>)

    {data_host_protocol_code, data_ip_addr, data_port} =
      handle_hpai(<<data_endpoint::size(@hpai_structure_length)-unit(8)>>)

    {control_ip_addr, control_port} =
      if control_ip_addr == 0 && control_port == 0,
        do: src,
        else: {control_ip_addr, control_port}

    ip_frame = %{
      ip_frame
      | control_host_protocol_code: control_host_protocol_code,
        control_endpoint: {control_ip_addr, control_port},
        data_host_protocol_code: data_host_protocol_code,
        data_endpoint: {data_ip_addr, data_port}
    }

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

    {con_tab, result} =
      ConTab.open(con_tab, ip_frame.con_type, %Ep{
        protocol: decode_host_protocol(data_host_protocol_code),
        ip_addr: data_ip_addr,
        port: data_port
      })

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

  defp handle_body(
         src,
         %IPFrame{service_type_id: service_type_id(:connectionstate_req)} = ip_frame,
         <<
           channel_id::8,
           0::8,
           control_endpoint::size(@hpai_structure_length)-unit(8)
         >>
       ) do
    {control_host_protocol_code, control_ip_addr, control_port} =
      handle_hpai(<<control_endpoint::size(@hpai_structure_length)-unit(8)>>)

    {control_ip_addr, control_port} =
      if control_ip_addr == 0 && control_port == 0,
        do: src,
        else: {control_ip_addr, control_port}

    con_tab = Cache.get(:con_tab)
    status = if ConTab.is_open?(con_tab, channel_id), do: :no_error, else: :connection_id

    ip_frame = %{
      ip_frame
      | control_host_protocol_code: control_host_protocol_code,
        control_endpoint: {control_ip_addr, control_port},
        channel_id: channel_id,
        status: status
    }

    [connectionstate_resp(ip_frame)]
  end

  defp handle_body(
         src,
         %IPFrame{service_type_id: service_type_id(:disconnect_req)} = ip_frame,
         <<
           channel_id::8,
           0::8,
           control_endpoint::size(@hpai_structure_length)-unit(8)
         >>
       ) do
    {control_host_protocol_code, control_ip_addr, control_port} =
      handle_hpai(<<control_endpoint::size(@hpai_structure_length)-unit(8)>>)

    {control_ip_addr, control_port} =
      if control_ip_addr == 0 && control_port == 0,
        do: src,
        else: {control_ip_addr, control_port}

    ip_frame = %{
      ip_frame
      | control_host_protocol_code: control_host_protocol_code,
        control_endpoint: {control_ip_addr, control_port},
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

  defp handle_body(
         _src,
         %IPFrame{service_type_id: service_type_id(:device_configuration_req)} = ip_frame,
         <<
           _structure_length::8,
           channel_id::8,
           ext_seq_counter::8,
           0::8,
           cemi_message_code::8,
           object_type::16,
           object_instance::8,
           pid::8,
           elems::4,
           start::12,
           data::bits
         >>
       ) do
    con_tab = Cache.get(:con_tab)

    # TODO how does the server react if no connection is open? (not specified)
    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.ext_seq_counter_equal?(con_tab, channel_id, ext_seq_counter) do
      con_tab = ConTab.increment_ext_seq_counter(con_tab, channel_id)
      Cache.put(:con_tab, con_tab)

      mgmt_cemi_frame = %MgmtCEMIFrame{
        message_code: decode_cemi_message_code(cemi_message_code),
        object_type: object_type,
        object_instance: object_instance,
        pid: pid,
        elems: elems,
        start: start,
        data: data
      }

      ip_frame = %{
        ip_frame
        | channel_id: channel_id,
          status: :no_error,
          ext_seq_counter: ext_seq_counter,
          data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id),
          cemi: mgmt_cemi_frame
      }

      [device_configuration_ack(ip_frame)] ++ device_configuration_req(ip_frame)
    else
      []
    end
  end

  defp handle_body(
         _src,
         %IPFrame{service_type_id: service_type_id(:device_configuration_ack)},
         <<
           4::8,
           channel_id::8,
           int_seq_counter::8,
           _status::8
         >>
       ) do
    con_tab = Cache.get(:con_tab)

    # TODO how should ACKs be handled by the server? (not specified)
    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.int_seq_counter_equal?(con_tab, channel_id, int_seq_counter) do
      con_tab = ConTab.increment_int_seq_counter(con_tab, channel_id)
      Cache.put(:con_tab, con_tab)
    end

    []
  end

  defp handle_body(
         src,
         %IPFrame{service_type_id: service_type_id(:tunnelling_req)} = ip_frame,
         <<
           4::8,
           channel_id::8,
           ext_seq_counter::8,
           0::8,
           cemi_message_code::8,
           0::8,
           frame_type::1,
           0::1,
           # TODO 1 means, DL repetitions may be sent. how to handle this?
           repeat::1,
           _system_broadcast::1,
           prio::2,
           # for TP1, L2-Acks are requested independent of value
           _ack::1,
           _confirm::1,
           addr_t::1,
           hops::3,
           eff::4,
           src::16,
           dest::16,
           len::8,
           data::bits
         >>
       ) do
    con_tab = Cache.get(:con_tab)

    # TODO how does the server react if no connection is open? (not specified)
    if ConTab.is_open?(con_tab, channel_id) do
      cemi_frame = %CEMIFrame{
        message_code: cemi_message_code,
        frame_type: frame_type,
        repeat: repeat,
        prio: prio,
        addr_t: addr_t,
        hops: hops,
        eff: eff,
        src: src,
        dest: dest,
        len: len,
        data: data
      }

      ip_frame = %{
        ip_frame
        | channel_id: channel_id,
          ext_seq_counter: ext_seq_counter,
          data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id),
          cemi: cemi_frame
      }

      cond do
        ConTab.ext_seq_counter_equal?(con_tab, channel_id, ext_seq_counter) ->
          con_tab = ConTab.increment_ext_seq_counter(con_tab, channel_id)
          Cache.put(:con_tab, con_tab)

          [tunneling_ack(ip_frame), {:dl, :req, ip_frame.cemi}]

        ConTab.ext_seq_counter_equal?(con_tab, channel_id, ext_seq_counter - 1) ->
          ip_frame = %{
            ip_frame
            | ext_seq_counter: ext_seq_counter - 1
          }

          [tunneling_ack(ip_frame)]

        true ->
          []
      end
    else
      []
    end
  end

  defp handle_hpai(<<
         @hpai_structure_length::8,
         host_protocol_code::8,
         ip_addr::32,
         port::16
       >>) do
    {host_protocol_code, ip_addr, port}
  end

  defp handle_cri(
         <<_cri_structure_length::8, connection_type_code::8, connection_specific_info::bits>>
       ) do
    case decode_connection_type(connection_type_code) do
      :tunnel_con ->
        <<knx_layer::8, 0::8>> = connection_specific_info

        case decode_knx_layer(knx_layer) do
          :tunnel_linklayer -> {:tunnel_con, {knx_layer}}
          _ -> {:error, :connection_option}
        end

      :device_mgmt_con ->
        {:device_mgmt_con, {}}

      _ ->
        {:error, :connection_type}
    end
  end

  # defp handle_cemi_service_info(
  #        cemi_message_code,
  #        <<
  #          # do we need to save the frame type?
  #          _frame_type::2,
  #          # TODO
  #          _repeat::1,
  #          # System Broadcast not applicable on TP1
  #          _system_broadcast::1,
  #          prio::2,
  #          # TP1: whether an ack is requested is determined by primitive
  #          _ack::1,
  #          # how do we handle this confirmation flag? is it identical with ok?
  #          confirm::1,
  #          addr_t::1,
  #          hops::3,
  #          eff::4,
  #          src::16,
  #          dest::16,
  #          len::8,
  #          data::bits
  #        >>
  #      ) do
  #   %CEMIFrame{
  #     message_code: cemi_message_code,
  #     src: src,
  #     dest: dest,
  #     addr_t: addr_t,
  #     prio: prio,
  #     hops: hops,
  #     len: len,
  #     data: data,
  #     eff: eff,
  #     confirm: confirm
  #   }
  # end

  defp search_resp(%IPFrame{control_host_protocol_code: code, control_endpoint: dest}) do
    frame =
      <<
        @header_size::8,
        @protocol_version::8,
        service_type_id(:search_resp)::16,
        @header_size + @hpai_structure_length + @dib_device_info_structure_length +
          @dib_supp_svc_families_structure_length::16
      >> <>
        hpai(code) <>
        dib_device_information() <>
        dib_supp_svc_families()

    {:ethernet, :transmit, {decode_host_protocol(code), dest, frame}}
  end

  defp description_resp(%IPFrame{
         control_host_protocol_code: control_host_protocol_code,
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

    {:ethernet, :transmit, {decode_host_protocol(control_host_protocol_code), dest, frame}}
  end

  defp connect_resp(
         %IPFrame{
           control_host_protocol_code: control_host_protocol_code,
           control_endpoint: dest,
           data_host_protocol_code: data_host_protocol_code,
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
        hpai(data_host_protocol_code) <>
        crd(ip_frame)

    {:ethernet, :transmit, {decode_host_protocol(control_host_protocol_code), dest, frame}}
  end

  defp connectionstate_resp(%IPFrame{
         control_host_protocol_code: control_host_protocol_code,
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

    {:ethernet, :transmit, {decode_host_protocol(control_host_protocol_code), dest, frame}}
  end

  defp disconnect_resp(%IPFrame{
         control_host_protocol_code: control_host_protocol_code,
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

    {:ethernet, :transmit, {decode_host_protocol(control_host_protocol_code), dest, frame}}
  end

  defp device_configuration_req(%IPFrame{
         channel_id: channel_id,
         data_endpoint: data_endpoint,
         cemi: received_cemi_frame
       }) do
    case mgmt_cemi_frame(received_cemi_frame) do
      :no_reply ->
        []

      {cemi_frame_size, conf_cemi_frame} ->
        con_tab = Cache.get(:con_tab)
        int_seq_counter = ConTab.get_int_seq_counter(con_tab, channel_id)

        conf_frame =
          <<
            @header_size::8,
            @protocol_version::8,
            service_type_id(:device_configuration_req)::16,
            10 + cemi_frame_size::16,
            4::8,
            channel_id::8,
            int_seq_counter::8,
            0::8
          >> <> conf_cemi_frame

        [{:ethernet, :transmit, {data_endpoint, conf_frame}}]
    end
  end

  defp mgmt_cemi_frame(%MgmtCEMIFrame{
         message_code: message_code,
         object_type: object_type,
         object_instance: object_instance,
         pid: pid,
         elems: elems,
         start: start,
         data: data
       }) do
    # TODO propinfo, funcpropcommand, funcpropstateread, reset
    case message_code do
      :m_propread_req ->
        props =
          case object_type do
            object_type(:device) -> Cache.get_obj(:device)
            object_type(:knxnet_ip_parameter) -> Cache.get_obj(:knxnet_ip_parameter)
          end

        case P.read_prop(props, 0, pid: pid, elems: elems, start: start) do
          {:ok, _, new_data} ->
            {7 + byte_size(new_data),
             <<
               cemi_message_code(:m_propread_con)::8,
               object_type::16,
               object_instance::8,
               pid::8,
               elems::4,
               start::12
             >> <>
               new_data}

          # TODO more specific error codes for prop read failure given in 03_06_03, 4.1.7.3.7.2
          {:error, _} ->
            {8,
             <<
               cemi_message_code(:m_propread_con)::8,
               object_type::16,
               object_instance::8,
               pid::8,
               0::4,
               start::12,
               0::8
             >>}
        end

      :m_propread_con ->
        :no_reply

      :m_propwrite_req ->
        props =
          case object_type do
            object_type(:device) -> Cache.get_obj(:device)
            object_type(:knxnet_ip_parameter) -> Cache.get_obj(:knxnet_ip_parameter)
          end

        # TODO more specific error codes for prop write failure given in 03_06_03, 4.1.7.3.7.2
        case P.write_prop(nil, props, 0,
               pid: pid,
               elems: elems,
               start: start,
               data: data
             ) do
          {:ok, props, _} ->
            Cache.put_obj(decode_object_type(object_type), props)

            {7,
             <<
               cemi_message_code(:m_propwrite_con)::8,
               object_type::16,
               object_instance::8,
               pid::8,
               elems::4,
               start::12
             >>}

          {:error, _} ->
            {8,
             <<
               cemi_message_code(:m_propwrite_con)::8,
               object_type::16,
               object_instance::8,
               pid::8,
               0::4,
               start::12,
               0::8
             >>}
        end

      :m_propwrite_con ->
        :no_reply
    end
  end

  defp device_configuration_ack(%IPFrame{
         channel_id: channel_id,
         ext_seq_counter: ext_seq_counter,
         status: status,
         data_endpoint: data_endpoint
       }) do
    frame = <<
      @header_size::8,
      @protocol_version::8,
      service_type_id(:device_configuration_ack)::16,
      10::16,
      4::8,
      channel_id::8,
      ext_seq_counter::8,
      device_configuration_ack_status_code(status)::8
    >>

    {:ethernet, :transmit, {data_endpoint, frame}}
  end

  defp tunneling_ack(%IPFrame{
         channel_id: channel_id,
         ext_seq_counter: ext_seq_counter,
         data_endpoint: data_endpoint
       }) do
    frame = <<
      @header_size::8,
      @protocol_version::8,
      service_type_id(:tunnelling_ack)::16,
      10::16,
      4::8,
      channel_id::8,
      ext_seq_counter::8,
      0::8
    >>

    {:ethernet, :transmit, {data_endpoint, frame}}
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

  defp decode_host_protocol(host_protocol_code) do
    case host_protocol_code do
      1 -> :udp
      2 -> :tcp
    end
  end

  defp decode_connection_type(connection_type_code) do
    case connection_type_code do
      3 -> :device_mgmt_con
      4 -> :tunnel_con
      6 -> :remlog_con
      7 -> :remconf_con
      8 -> :objsvr_con
    end
  end

  defp decode_knx_layer(knx_layer) do
    case knx_layer do
      0x02 -> :tunnel_linklayer
      0x04 -> :tunnel_raw
      0x80 -> :tunnel_busmonitor
    end
  end

  defp decode_cemi_message_code(cemi_message_code) do
    case cemi_message_code do
      0xFC -> :m_propread_req
      0xFB -> :m_propread_con
      0xF6 -> :m_propwrite_req
      0xF5 -> :m_propwrite_con
      0xF7 -> :m_propinfo_ind
      0xF8 -> :m_funcpropcommand_req
      0xFA -> :m_funcpropcommand_con
      0xF9 -> :m_funcpropstateread_req
      0xF1 -> :m_reset_req
      0xF0 -> :m_reset_ind
    end
  end

  defp decode_object_type(object_type) do
    case object_type do
      0 -> :device
      1 -> :addr_tab
      2 -> :assoc_tab
      3 -> :app_prog
      4 -> :interface_prog
      6 -> :router
      7 -> :cemi_server
      9 -> :go_tab
      11 -> :knxnet_ip_parameter
      13 -> :file_server
    end
  end
end
