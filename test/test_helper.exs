ExUnit.start()

# :dbg.start()
# :dbg.tracer()
# :dbg.tpl(Knx.Stack.Tl, :handle, [{:_, [], [{:return_trace}]}])
# :dbg.p(:all, :call)

defmodule Helper do
  import Knx.Defs
  require Knx.Defs
  alias Knx.Ail.Property, as: P
  alias Knx.Ail.GroupObject, as: GO

  import Bitwise

  @addr_tab [-1, 1, 2, 3, 4, 5, 6]

  @assoc_tab [
    {1, 1},
    {2, 2},
    {3, 3},
    {4, 4},
    {5, 5},
    {6, 6}
  ]

  @go_tab %{
    1 => %GO{asap: 1, transmits: true},
    2 => %GO{asap: 2, writable: true},
    3 => %GO{asap: 3, readable: true},
    4 => %GO{asap: 4, updatable: true},
    5 => %GO{asap: 5, transmits: true, readable: true},
    6 => %GO{asap: 6, transmits: true, readable: true, updatable: true}
  }

  @go_values %{
    1 => [<<0::6>>],
    2 => [<<0::6>>],
    3 => [<<0::6>>],
    4 => [<<0::6>>],
    5 => [<<0::6>>],
    6 => [<<0::6>>]
  }

  # IO
  @serial 0x112233445566
  @subnet_addr 0xFF
  @device_addr 0xFF
  @desc 0x07B0
  @device_ctrl %{
    safe_state: false,
    verify_mode: false,
    ia_duplication: false,
    user_stopped: false
  }

  # ---

  def get_assoc_tab(), do: @assoc_tab
  def get_go_tab(), do: @go_tab
  def get_addr_tab(), do: @addr_tab
  def get_go_values(), do: @go_values

  def get_device_props(prog_mode, verify \\ false) do
    device_ctrl = %{@device_ctrl | verify_mode: verify}

    [
      P.new(:object_type, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:load_state_ctrl, [load_state(:unloaded)], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:serial, [@serial], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:manu_id, [0xAFFE], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:device_ctrl, [device_ctrl], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:order_info, [0x0815], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:version, [0x0001], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:routing_count, [3], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:prog_mode, [prog_mode], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:max_apdu_length, [15], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:subnet_addr, [@subnet_addr], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:device_addr, [@device_addr], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:hw_type, [0xAABBCCDDEEFF], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:device_descriptor, [@desc], max: 1, write: false, r_lvl: 3, w_lvl: 0)
    ]
  end

  def get_table_props(object_type, mem_ref) do
    [
      P.new(:object_type, [object_type], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:load_state_ctrl, [load_state(:unloaded)], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0)
      # Table                 23 = PID_TABLE      PDT_UNSIGNED_INT[]
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
      # Error code            28 = PID_ERROR_CODE PDT_ENUM8
    ]
  end

  def convert_ip_to_number({e3, e2, e1, e0}) do
    (e3 <<< 24) + (e2 <<< 16) + (e1 <<< 8) + e0
  end
end

defmodule Telegram do
  alias Knx.KnxnetIp.Knip
  alias Knx.KnxnetIp.Parameter, as: KnipParameter

  require Knx.Defs
  import Knx.Defs

  @ip_interface_ip Application.compile_env(:knx, :ip_addr, {0, 0, 0, 0})
  @ip_interface_ip_num Knip.convert_ip_to_number(@ip_interface_ip)
  @ip_interface_port 3671

  @ets_ip {192, 168, 178, 21}
  @ets_ip_num Knip.convert_ip_to_number(@ets_ip)
  @ets_port_discovery 60427
  @ets_port_control 52250
  @ets_port_device_mgmt_data 52252
  @ets_port_tunnelling_data 52252

  @knx_medium knx_medium_code(Application.compile_env(:knx, :knx_medium, :tp1))
  @device_status 1
  @knx_indv_addr Application.compile_env(:knx, :knx_indv_addr, 0x1101)
  @project_installation_id 0x0000
  @serial 0x112233445566
  @multicast_addr 0xE000170C
  @mac_addr Application.compile_env(:knx, :mac_addr, 0x000000000000)
  @friendly_name Application.compile_env(:knx, :friendly_name, "empty name (KNXnet/IP)")
                 |> KnipParameter.convert_friendly_name()

  # ----------------------------------------------------------------------------
  # core

  def search_req() do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:search_req)::8,
      structure_length(:header) + structure_length(:hpai)::16,
      # HPAI ---------------
      structure_length(:hpai)::8,
      protocol_code(:udp)::8,
      @ets_ip_num::32,
      @ets_port_discovery::16
    >>
  end

  def search_resp(knx_device_type) do
    {dib_supp_svc_families_length, tail} =
      case knx_device_type do
        :knx_ip_interface ->
          {8, <<service_family_id(:tunnelling)::8, protocol_version(:tunnelling)::8>>}

        :knx_ip ->
          {6, <<>>}
      end

    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:search_resp)::8,
      structure_length(:header) + structure_length(:hpai) + structure_length(:dib_device_info) +
        dib_supp_svc_families_length::16,
      # HPAI ---------------
      structure_length(:hpai)::8,
      protocol_code(:udp)::8,
      @ip_interface_ip_num::32,
      @ip_interface_port::16,
      # DIB Device Info ---------------
      structure_length(:dib_device_info)::8,
      description_type_code(:device_info)::8,
      @knx_medium::8,
      @device_status::8,
      @knx_indv_addr::16,
      @project_installation_id::16,
      @serial::48,
      @multicast_addr::32,
      @mac_addr::48,
      @friendly_name::8*30,
      # DIB Supported Service Families ---------------
      dib_supp_svc_families_length::8,
      description_type_code(:supp_svc_families)::8,
      service_family_id(:core)::8,
      protocol_version(:core)::8,
      service_family_id(:device_management)::8,
      protocol_version(:device_management)::8
    >> <>
      tail
  end

  def description_req() do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:description_req)::8,
      structure_length(:header) + structure_length(:hpai)::16,
      # HPAI ---------------
      structure_length(:hpai)::8,
      protocol_code(:udp)::8,
      @ets_ip_num::32,
      @ets_port_control::16
    >>
  end

  def description_resp(knx_device_type) do
    {dib_supp_svc_families_length, tail} =
      case knx_device_type do
        :knx_ip_interface ->
          {8, <<service_family_id(:tunnelling)::8, protocol_version(:tunnelling)::8>>}

        :knx_ip ->
          {6, <<>>}
      end

    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:description_resp)::8,
      structure_length(:header) + structure_length(:dib_device_info) +
        dib_supp_svc_families_length::16,
      # DIB Device Info ---------------
      structure_length(:dib_device_info)::8,
      description_type_code(:device_info)::8,
      @knx_medium::8,
      @device_status::8,
      @knx_indv_addr::16,
      @project_installation_id::16,
      @serial::48,
      @multicast_addr::32,
      @mac_addr::48,
      @friendly_name::8*30,
      # DIB Supported Service Families ---------------
      dib_supp_svc_families_length::8,
      description_type_code(:supp_svc_families)::8,
      service_family_id(:core)::8,
      protocol_version(:core)::8,
      service_family_id(:device_management)::8,
      protocol_version(:device_management)::8
    >> <>
      tail
  end

  def connect_req(type, options \\ []) do
    con_type = Keyword.get(options, :con_type, nil)
    tunnelling_knx_layer = Keyword.get(options, :tunnelling_knx_layer, nil)

    {cri_type, ets_port, cri} =
      case type do
        :device_management ->
          {:cri_device_mgmt_con, @ets_port_device_mgmt_data,
           <<structure_length(:cri_device_mgmt_con)::8, con_type_code(:device_mgmt_con)::8>>}

        :tunnelling ->
          {:cri_tunnel_con, @ets_port_tunnelling_data,
           <<structure_length(:cri_tunnel_con)::8, con_type_code(con_type)::8,
             tunnelling_knx_layer_code(tunnelling_knx_layer)::8,
             knxnetip_constant(:reserved)::8>>}
      end

    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:connect_req)::8,
      Knip.get_structure_length([
        :header,
        :hpai,
        :hpai,
        cri_type
      ])::16,
      # HPAI ---------------
      structure_length(:hpai)::8,
      protocol_code(:udp)::8,
      @ets_ip_num::32,
      @ets_port_control::16,
      # HPAI ---------------
      structure_length(:hpai)::8,
      protocol_code(:udp)::8,
      @ets_ip_num::32,
      ets_port::16
    >> <>
      cri
  end

  def connect_resp(:no_error, type, channel_id) do
    crd =
      case type do
        :device_management ->
          <<structure_length(:crd_device_mgmt_con)::8, con_type_code(:device_mgmt_con)::8>>

        :tunnelling ->
          <<structure_length(:crd_tunnel_con)::8, con_type_code(:tunnel_con)::8,
            @knx_indv_addr::16>>
      end

    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:connect_resp)::8,
      structure_length(:header) + structure_length(:connection_header_core) +
        structure_length(:hpai) + byte_size(crd)::16,
      # Connection Header ---------------
      channel_id::8,
      connect_response_status_code(:no_error)::8,
      # HPAI ---------------
      structure_length(:hpai)::8,
      protocol_code(:udp)::8,
      @ip_interface_ip_num::32,
      @ip_interface_port::16
    >> <>
      crd
  end

  def connect_resp(:error, error_type) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:connect_resp)::8,
      structure_length(:header) + 2::16,
      0::8,
      connect_response_status_code(error_type)::8
    >>
  end

  def connectionstate_req(channel_id) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:connectionstate_req)::8,
      structure_length(:header) + structure_length(:connection_header_core) +
        structure_length(:hpai)::16,
      # Connection Header ---------------
      channel_id::8,
      knxnetip_constant(:reserved)::8,
      # HPAI ---------------
      structure_length(:hpai)::8,
      protocol_code(:udp)::8,
      @ets_ip_num::32,
      @ets_port_control::16
    >>
  end

  def connectionstate_resp(channel_id, status_code) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:connectionstate_resp)::8,
      structure_length(:header) + structure_length(:connection_header_core)::16,
      # Connection Header ---------------
      channel_id::8,
      connectionstate_response_status_code(status_code)::8
    >>
  end

  def disconnect_req(channel_id, ip \\ nil, port \\ nil) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:disconnect_req)::8,
      structure_length(:header) + structure_length(:connection_header_core) +
        structure_length(:hpai)::16,
      # Connection Header ---------------
      channel_id::8,
      knxnetip_constant(:reserved)::8,
      # HPAI ---------------
      structure_length(:hpai)::8,
      protocol_code(:udp)::8,
      if(ip, do: Knip.convert_ip_to_number(ip), else: @ets_ip_num)::32,
      if(port, do: port, else: @ets_port_control)::16
    >>
  end

  def disconnect_resp(channel_id) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:core)::8,
      service_type_id(:disconnect_resp)::8,
      structure_length(:header) + structure_length(:connection_header_core)::16,
      # Connection Header ---------------
      channel_id::8,
      common_error_code(:no_error)::8
    >>
  end

  # ----------------------------------------------------------------------------
  # Device Management

  def device_configuration_req(
        channel_id,
        seq_counter,
        cemi_message_type,
        pid,
        elems,
        start,
        data
      ) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:device_management)::8,
      service_type_id(:device_configuration_req)::8,
      structure_length(:header) + structure_length(:connection_header_device_management) + 7 +
        byte_size(data)::16,
      # Connection header ---------------
      structure_length(:connection_header_device_management)::8,
      channel_id::8,
      seq_counter::8,
      knxnetip_constant(:reserved)::8,
      # cEMI ---------------
      cemi_message_code(cemi_message_type)::8,
      0::16,
      1::8,
      pid::8,
      elems::4,
      start::12
    >> <>
      <<data::bits>>
  end

  def device_configuration_req(channel_id, seq_counter, :m_reset_req) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:device_management)::8,
      service_type_id(:device_configuration_req)::8,
      structure_length(:header) + structure_length(:connection_header_device_management) + 1::16,
      # Connection header ---------------
      structure_length(:connection_header_device_management)::8,
      channel_id::8,
      seq_counter::8,
      knxnetip_constant(:reserved)::8,
      # cEMI ---------------
      cemi_message_code(:m_reset_req)::8
    >>
  end

  def device_configuration_ack(channel_id, seq_counter, error_code) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:device_management)::8,
      service_type_id(:device_configuration_ack)::8,
      structure_length(:header) + structure_length(:connection_header_device_management)::16,
      # Connection header ---------------
      structure_length(:connection_header_device_management)::8,
      channel_id::8,
      seq_counter::8,
      common_error_code(error_code)::8
    >>
  end

  # ----------------------------------------------------------------------------
  # Tunnelling

  def data_cemi_frame(
        primitive,
        confirm,
        src,
        dest,
        data
      ) do
    len = byte_size(data) - 1
    frame_type = if(len <= 15, do: 1, else: 0)

    <<
      cemi_message_code(primitive)::8,
      0::8,
      frame_type::1,
      0::1,
      0::1,
      1::1,
      0::2,
      0::1,
      confirm::1,
      0::1,
      7::3,
      0::4,
      src::16,
      dest::16,
      len::8,
      data::bits
    >>
  end

  def tunnelling_req(
        channel_id,
        seq_counter,
        cemi_frame
      ) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:tunnelling)::8,
      service_type_id(:tunnelling_req)::8,
      structure_length(:header) + structure_length(:connection_header_tunnelling) +
        byte_size(cemi_frame)::16,
      # Connection header ---------------
      structure_length(:connection_header_tunnelling)::8,
      channel_id::8,
      seq_counter::8,
      knxnetip_constant(:reserved)::8
    >> <> cemi_frame
  end

  def tunnelling_ack(channel_id, seq_counter) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:tunnelling)::8,
      service_type_id(:tunnelling_ack)::8,
      structure_length(:header) + structure_length(:connection_header_tunnelling)::16,
      # Connection header ---------------
      structure_length(:connection_header_tunnelling)::8,
      channel_id::8,
      seq_counter::8,
      common_error_code(:no_error)::8
    >>
  end

  # ----------------------------------------------------------------------------
  # Routing

  def routing_ind(cemi_frame) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:routing)::8,
      service_type_id(:routing_ind)::8,
      structure_length(:header) + byte_size(cemi_frame)::16
    >> <>
      cemi_frame
  end

  def routing_busy(wait_time, control_field) do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:routing)::8,
      service_type_id(:routing_busy)::8,
      structure_length(:header) + structure_length(:busy_info)::16,
      # Busy Info ---------------
      structure_length(:busy_info)::8,
      0::8,
      wait_time::16,
      control_field::16
    >>
  end

  def routing_lost_message() do
    <<
      # Header ---------------
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_family_id(:routing)::8,
      service_type_id(:routing_lost_message)::8,
      structure_length(:header) + structure_length(:lost_message_info)::16,
      # Lost Message Info ---------------
      structure_length(:lost_message_info)::8,
      0::8,
      0::16
    >>
  end
end
