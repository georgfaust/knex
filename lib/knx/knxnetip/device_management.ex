defmodule Knx.KnxnetIp.DeviceManagement do
  alias Knx.KnxnetIp.IpInterface, as: Ip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.MgmtCemiFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.Ail.Property, as: P

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  # ----------------------------------------------------------------------------
  # body handlers

  '''
  DEVICE CONFIGURATION REQUEST
  Description: 2.3.2
  Structure: 4.2.6
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:device_configuration_req)} = ip_frame,
        <<
          structure_length(:connection_header)::8,
          channel_id::8,
          client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
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

    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.client_seq_counter_equal?(con_tab, channel_id, client_seq_counter) do
      con_tab = ConTab.increment_client_seq_counter(con_tab, channel_id)
      Cache.put(:con_tab, con_tab)

      mgmt_cemi_frame = %MgmtCemiFrame{
        message_code: cemi_message_code,
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
          status: common_error_code(:no_error),
          client_seq_counter: client_seq_counter,
          data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id),
          cemi: mgmt_cemi_frame
      }

      [{:timer, :restart, {:ip_connection, channel_id}}, device_configuration_ack(ip_frame)] ++
        device_configuration_req(ip_frame)
    else
      # [XXXI]
      []
    end
  end

  '''
  M_RESET_REQ
  Description & Structure: 03_06_03:4.1.7.5.1
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:device_configuration_req)},
        <<
          structure_length(:connection_header)::8,
          _channel_id::8,
          _client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          cemi_message_code(:m_reset_req)::8
        >>
      ) do
    # TODO trigger device restart
    []
  end

  '''
  DEVICE CONFIGURATION ACK
  Description: 2.3.2
  Structure: 4.2.7
  '''

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:device_configuration_ack)},
        <<
          structure_length(:connection_header)::8,
          channel_id::8,
          server_seq_counter::8,
          _status::8
        >>
      ) do
    con_tab = Cache.get(:con_tab)

    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.server_seq_counter_equal?(con_tab, channel_id, server_seq_counter) do
      Cache.put(:con_tab, ConTab.increment_server_seq_counter(con_tab, channel_id))

      [
        {:timer, :restart, {:ip_connection, channel_id}},
        {:timer, :stop, {:device_management_req, server_seq_counter}}
      ]
    else
      []
    end
  end

  def handle_body(_ip_frame, _frame) do
    warning(:no_matching_handler)
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  '''
  DEVICE CONFIGURATION REQUEST
  Description: 2.3.2
  Structure: 4.2.6
  '''

  defp device_configuration_req(%IpFrame{
         channel_id: channel_id,
         data_endpoint: data_endpoint,
         cemi: received_cemi_frame
       }) do
    case mgmt_cemi_frame(received_cemi_frame) do
      :no_reply ->
        []

      conf_cemi_frame ->
        conf_frame =
          Ip.header(
            service_type_id(:device_configuration_req),
            structure_length(:header) + byte_size(conf_cemi_frame) +
              connection_header_structure_length(:device_management)
          ) <>
            connection_header(
              channel_id,
              ConTab.get_server_seq_counter(Cache.get(:con_tab), channel_id),
              knxnetip_constant(:reserved)
            ) <>
            conf_cemi_frame

        [
          {:ethernet, :transmit, {data_endpoint, conf_frame}},
          # TODO set device_configuration_request_timeout = 10s
          {:timer, :start,
           {:device_management_req,
            ConTab.get_server_seq_counter(Cache.get(:con_tab), channel_id)}}
        ]
    end
  end

  '''
  DEVICE CONFIGURATION ACK
  Description: 2.3.2
  Structure: 4.2.7
  '''

  defp device_configuration_ack(%IpFrame{
         channel_id: channel_id,
         client_seq_counter: client_seq_counter,
         status: status,
         data_endpoint: data_endpoint
       }) do
    frame =
      Ip.header(
        service_type_id(:device_configuration_ack),
        structure_length(:header) + connection_header_structure_length(:device_management)
      ) <>
        connection_header(
          channel_id,
          client_seq_counter,
          status
        )

    {:ethernet, :transmit, {data_endpoint, frame}}
  end

  # ----------------------------------------------------------------------------
  # management cemi frame creators

  '''
  M_PROPREAD_X
  Description & Structure: 03_06_03:4.1.7.3.2 ff.
  '''

  # TODO implement funcpropcommand, funcpropstateread
  defp mgmt_cemi_frame(%MgmtCemiFrame{
         message_code: cemi_message_code(:m_propread_req),
         object_type: object_type,
         object_instance: object_instance,
         pid: pid,
         elems: elems,
         start: start
       }) do
    # !info: alternatively, use a wrapper function for P.read_prop in Device and KnxnetIp_parameter?
    case P.read_prop(get_object(object_type), 0, pid: pid, elems: elems, start: start) do
      {:ok, _, new_data} ->
        <<
          cemi_message_code(:m_propread_con)::8,
          object_type::16,
          object_instance::8,
          pid::8,
          elems::4,
          start::12
        >> <>
          new_data

      # TODO more specific error codes for prop read failure given in 03_06_03, 4.1.7.3.7.2
      {:error, _} ->
        <<
          cemi_message_code(:m_propread_con)::8,
          object_type::16,
          object_instance::8,
          pid::8,
          # 0 elems signals error
          0::4,
          start::12,
          cemi_error_code(:unspecific)
        >>
    end
  end

  defp mgmt_cemi_frame(%MgmtCemiFrame{message_code: cemi_message_code(:m_propread_con)}) do
    :no_reply
  end

  '''
  M_PROPWRITE_X
  Description & Structure: 03_06_03:4.1.7.3.4 ff.
  '''

  defp mgmt_cemi_frame(%MgmtCemiFrame{
         message_code: cemi_message_code(:m_propwrite_req),
         object_type: object_type,
         object_instance: object_instance,
         pid: pid,
         elems: elems,
         start: start,
         data: data
       }) do
    case P.write_prop(nil, get_object(object_type), 0,
           pid: pid,
           elems: elems,
           start: start,
           data: data
         ) do
      {:ok, props, _} ->
        Cache.put_obj(decode_object_type(object_type), props)

        <<
          cemi_message_code(:m_propwrite_con)::8,
          object_type::16,
          object_instance::8,
          pid::8,
          elems::4,
          start::12
        >>

      # TODO more specific error codes for prop write failure given in 03_06_03, 4.1.7.3.7.2
      {:error, _} ->
        <<
          cemi_message_code(:m_propwrite_con)::8,
          object_type::16,
          object_instance::8,
          pid::8,
          # 0 elems signals error
          0::4,
          start::12,
          cemi_error_code(:unspecific)
        >>
    end
  end

  defp mgmt_cemi_frame(%MgmtCemiFrame{message_code: cemi_message_code(:m_propwrite_con)}) do
    :no_reply
  end

  '''
  M_PROPINFO_IND
  Description & Structure: 03_06_03:4.1.7.3.6
  '''

  # TODO M_PropInfo.ind shall be sent to inform client about changed property value
  #  (change not triggered by client via PropWrite) 03_06_03: 4.1.7.3.6

  # defp mgmt_cemi_frame(
  #        object_type,
  #        object_instance,
  #        pid,
  #        elems,
  #        start
  #      ) do
  #   # !info: instead of atom, use object_type(atom) as key in Cache?

  #   # !info: alternatively, use a wrapper function for P.read_prop in Device and KnxnetIp_parameter?
  #   case P.read_prop(get_object(object_type), 0, pid: pid, elems: elems, start: start) do
  #     {:ok, _, new_data} ->
  #       <<
  #         cemi_message_code(:m_propinfo_ind)::8,
  #         object_type::16,
  #         object_instance::8,
  #         pid::8,
  #         elems::4,
  #         start::12
  #       >> <>
  #         new_data

  #     {:error, _} ->
  #       :no_reply
  #   end
  # end

  # ----------------------------------------------------------------------------
  # placeholder creators

  defp connection_header(channel_id, seq_counter, last_octet) do
    <<
      connection_header_structure_length(:device_management),
      channel_id::8,
      seq_counter::8,
      last_octet::8
    >>
  end

  # ----------------------------------------------------------------------------
  # helper functions

  defp decode_object_type(object_type) do
    case object_type do
      0 -> :device
      11 -> :knxnet_ip_parameter
    end
  end

  defp get_object(object_type) do
    # !info: instead of atom, use object_type(atom) as key in Cache?
    case object_type do
      object_type(:device) -> Cache.get_obj(:device)
      object_type(:knxnet_ip_parameter) -> Cache.get_obj(:knxnet_ip_parameter)
    end
  end
end
