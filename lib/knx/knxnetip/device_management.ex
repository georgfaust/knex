defmodule Knx.KnxnetIp.DeviceManagement do
  alias Knx.KnxnetIp.Knip
  alias Knx.KnxnetIp.IpFrame
  alias Knx.KnxnetIp.MgmtCemiFrame
  alias Knx.KnxnetIp.ConTab
  alias Knx.Ail.Property, as: P
  alias Knx.State.KnxnetIp, as: IpState

  require Knx.Defs
  import Knx.Defs
  import PureLogger

  @moduledoc """
  The DeviceManagement module handles the body of KNXnet/IP-frames of the identically named
  service family.

  As a result, the updated ip_state and a list of impulses/effects are returned.
  Impulses include the respective response frames.
  """

  # ----------------------------------------------------------------------------
  # body handlers

  @doc """
  Handles body of KNXnet/IP frames.

  ## KNX specification

  For further information on the request services, refer to the
  following sections in document 03_08_03 (KNXnet/IP Device Management):

    DEVICE_CONFIGURATION_REQUEST: section 2.3.2 (description) & 4.2.6 (structure)
    DEVICE_CONFIGURATION_ACK: section 2.3.2 (description) & 4.2.7 (structure)

  """
  def handle_body(
        %IpFrame{service_type_id: service_type_id(:device_configuration_req)} = ip_frame,
        <<
          structure_length(:connection_header_device_management)::8,
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
        >>,
        %IpState{con_tab: con_tab} = ip_state
      ) do
    if ConTab.client_seq_counter_equal?(con_tab, channel_id, client_seq_counter) do
      con_tab = ConTab.increment_client_seq_counter(con_tab, channel_id)

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
          status_code: common_error_code(:no_error),
          client_seq_counter: client_seq_counter,
          data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id),
          cemi: mgmt_cemi_frame
      }

      {%{ip_state | con_tab: con_tab},
       [
         {:timer, :restart, {:ip_connection, channel_id}},
         device_configuration_ack(ip_frame)
       ] ++
         device_configuration_req(ip_frame, con_tab)}
    else
      # [XXXI]
      {ip_state, []}
    end
  end

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:device_configuration_req)},
        <<
          structure_length(:connection_header_device_management)::8,
          _channel_id::8,
          _client_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          cemi_message_code(:m_reset_req)::8
        >>,
        %IpState{} = ip_state
      ) do
    {ip_state, [{:restart, :ind, :knip}]}
  end

  def handle_body(
        %IpFrame{service_type_id: service_type_id(:device_configuration_ack)},
        <<
          structure_length(:connection_header_device_management)::8,
          channel_id::8,
          server_seq_counter::8,
          _status_code::8
        >>,
        %IpState{con_tab: con_tab} = ip_state
      ) do
    if ConTab.server_seq_counter_equal?(con_tab, channel_id, server_seq_counter) do
      con_tab = ConTab.increment_server_seq_counter(con_tab, channel_id)

      {%{ip_state | con_tab: con_tab},
       [
         {:timer, :restart, {:ip_connection, channel_id}},
         {:timer, :stop, {:device_management_req, server_seq_counter}}
       ]}
    else
      {ip_state, []}
    end
  end

  def handle_body(_ip_frame, _frame, %IpState{} = ip_state) do
    warning(:no_matching_handler)
    {ip_state, []}
  end

  # ----------------------------------------------------------------------------
  # impulse creators

  ### [private doc]
  # Produces impulse for DEVICE_CONFIGURATION_REQUEST frame.
  #
  # KNX specification:
  #   Document 03_08_02, section 2.3.2 (description) & 4.2.6 (structure)
  defp device_configuration_req(
         %IpFrame{
           channel_id: channel_id,
           data_endpoint: data_endpoint,
           cemi: received_cemi_frame
         },
         con_tab
       ) do
    case mgmt_cemi_frame(received_cemi_frame) do
      :no_reply ->
        []

      conf_cemi_frame ->
        total_length =
          Knip.get_structure_length([:header, :connection_header_device_management]) +
            byte_size(conf_cemi_frame)

        header = Knip.header(service_type_id(:device_configuration_req), total_length)

        connection_header =
          connection_header(
            channel_id,
            ConTab.get_server_seq_counter(con_tab, channel_id),
            knxnetip_constant(:reserved)
          )

        body = connection_header <> conf_cemi_frame

        [
          {:ip, :transmit, {data_endpoint, header <> body}},
          {:timer, :start,
           {:device_management_req, ConTab.get_server_seq_counter(con_tab, channel_id)}}
        ]
    end
  end

  ### [private doc]
  # Produces impulse for DEVICE_CONFIGURATION_ACK frame.
  #
  # KNX specification:
  #   Document 03_08_02, section 2.3.2 (description) & 4.2.7 (structure)
  defp device_configuration_ack(%IpFrame{
         channel_id: channel_id,
         client_seq_counter: client_seq_counter,
         status_code: status_code,
         data_endpoint: data_endpoint
       }) do
    total_length = Knip.get_structure_length([:header, :connection_header_device_management])
    header = Knip.header(service_type_id(:device_configuration_ack), total_length)
    body = connection_header(channel_id, client_seq_counter, status_code)

    {:ip, :transmit, {data_endpoint, header <> body}}
  end

  # ----------------------------------------------------------------------------
  # management cemi frame creators

  ### [private doc]
  # Produces management cemi frame for M_PROPREAD_X services.
  #
  # KNX specification:
  #   Document 03_06_03, section 4.1.7.3.2 ff.
  defp mgmt_cemi_frame(%MgmtCemiFrame{
         message_code: cemi_message_code(:m_propread_req),
         object_type: object_type,
         object_instance: object_instance,
         pid: pid,
         elems: elems,
         start: start
       }) do
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

  ### [private doc]
  # Produces management cemi frame for M_PROPWRITE_X services.
  #
  # KNX specification:
  #   Document 03_06_03, section 4.1.7.3.4 ff.
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
      {:ok, props, _, _} ->
        Cache.put_obj(decode_object_type(object_type), props)

        <<
          cemi_message_code(:m_propwrite_con)::8,
          object_type::16,
          object_instance::8,
          pid::8,
          elems::4,
          start::12
        >>

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

  @doc """
  Produces management cemi frame for M_PROPWRITE_X services.

  M_PropInfo.ind shall be sent to inform client about changed property value
   (change not triggered by client via PropWrite)

  KNX specification:
    Document 03_06_03, section 4.1.7.3.6
  """
  def mgmt_cemi_frame(
        object_type,
        object_instance,
        pid,
        elems,
        start
      ) do
    case P.read_prop(get_object(object_type), 0, pid: pid, elems: elems, start: start) do
      {:ok, _, new_data} ->
        <<
          cemi_message_code(:m_propinfo_ind)::8,
          object_type::16,
          object_instance::8,
          pid::8,
          elems::4,
          start::12
        >> <>
          new_data

      {:error, _} ->
        :no_reply
    end
  end

  # ----------------------------------------------------------------------------
  # placeholder creators

  ### [private doc]
  # Produces Connection Header.
  #
  # KNX specification:
  #   Document 03_08_02, section 5.3.1 (description/structure)
  defp connection_header(channel_id, seq_counter, last_octet) do
    <<
      structure_length(:connection_header_device_management),
      channel_id::8,
      seq_counter::8,
      last_octet::8
    >>
  end

  # ----------------------------------------------------------------------------
  # helper functions

  ### [private doc]
  # Translates object type index to associated tuple.
  defp decode_object_type(object_type) do
    case object_type do
      0 -> :device
      11 -> :knxnet_ip_parameter
    end
  end

  ### [private doc]
  # Loads object from Cache.
  defp get_object(object_type) do
    case object_type do
      object_type(:device) -> Cache.get_obj(:device)
      object_type(:knxnet_ip_parameter) -> Cache.get_obj(:knxnet_ip_parameter)
    end
  end
end
