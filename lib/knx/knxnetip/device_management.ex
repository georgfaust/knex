defmodule Knx.Knxnetip.DeviceManagement do
  alias Knx.Knxnetip.IPFrame
  alias Knx.Knxnetip.MgmtCemiFrame
  alias Knx.Knxnetip.ConTab
  alias Knx.Ail.Property, as: P

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  def handle_body(
        _src,
        %IPFrame{service_type_id: service_type_id(:device_configuration_req)} = ip_frame,
        <<
          structure_length(:connection_header)::8,
          channel_id::8,
          ext_seq_counter::8,
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

    # TODO how does the server react if no connection is open? (not specified)
    if ConTab.is_open?(con_tab, channel_id) &&
         ConTab.ext_seq_counter_equal?(con_tab, channel_id, ext_seq_counter) do
      con_tab = ConTab.increment_ext_seq_counter(con_tab, channel_id)
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

  def handle_body(
        _src,
        %IPFrame{service_type_id: service_type_id(:device_configuration_ack)},
        <<
          structure_length(:connection_header)::8,
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

  def handle_body(_src, _ip_frame, _frame) do
    error(:unknown_service_type_id)
  end

  # ----------------------------------------------------------------------------

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
            structure_length(:header)::8,
            protocol_version(:knxnetip)::8,
            service_type_id(:device_configuration_req)::16,
            structure_length(:header) + structure_length(:connection_header) + cemi_frame_size::16,
            structure_length(:connection_header)::8,
            channel_id::8,
            int_seq_counter::8,
            knxnetip_constant(:reserved)::8
          >> <> conf_cemi_frame

        [{:ethernet, :transmit, {data_endpoint, conf_frame}}]
    end
  end

  defp mgmt_cemi_frame(%MgmtCemiFrame{
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
      cemi_message_code(:m_propread_req) ->
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
               # 0 elems signals error
               0::4,
               start::12,
               0::8
             >>}
        end

      cemi_message_code(:m_propread_con) ->
        :no_reply

      cemi_message_code(:m_propwrite_req) ->
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
               # 0 elems signals error
               0::4,
               start::12,
               cemi_error_code(:unspecific)
             >>}
        end

      cemi_message_code(:m_propwrite_con) ->
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
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_type_id(:device_configuration_ack)::16,
      structure_length(:device_configuration_ack)::16,
      structure_length(:connection_header)::8,
      channel_id::8,
      ext_seq_counter::8,
      device_configuration_ack_status_code(status)::8
    >>

    {:ethernet, :transmit, {data_endpoint, frame}}
  end

  # ----------------------------------------------------------------------------

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
