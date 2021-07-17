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

  use Bitwise

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

  def get_knxnetip_parameter_props() do
    current_ip_addr = 0xC0A8B23E
    current_subnet_mask = 0xFFFFFF00
    current_default_gateway = 0xC0A80001
    mac_addr = 0x0
    knx_addr = 0x11FF
    # friendly_name: "KNXnet/IP Device"
    friendly_name = 0x4B4E_586E_6574_2F49_5020_4465_7669_6365_0000_0000_0000_0000_0000_0000_0000

    [
      # TODO r_lvl
      P.new(:project_installation_id, [0x0000], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO has to be in sync with properties :subnet_addr and :device_addr of device object
      # TODO r_lvl, w_lvl
      P.new(:knx_individual_address, [knx_addr], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO first entry shall be length of list
      # TODO r_lvl, w_lvl, max
      P.new(:additional_individual_addresses, [0], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO current assignment method: DHCP; linked to ip_assignment_method?
      # TODO write, r_lvl, w_lvl
      P.new(:current_ip_assignment_method, [0x4], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO write, r_lvl, w_lvl
      P.new(:ip_assignment_method, [0x4], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO r_lvl
      P.new(:ip_capabilities, [0x1], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO shall be set according to Core, 8.5; linked to ip_address?
      # TODO r_lvl
      P.new(:current_ip_address, [current_ip_addr], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # linked to subnet_mask?
      # TODO write, r_lvl, w_lvl
      P.new(:current_subnet_mask, [current_subnet_mask], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # linked to default_gateway?
      # TODO write, r_lvl, w_lvl
      P.new(:current_default_gateway, [current_default_gateway],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      # TODO r_lvl
      P.new(:ip_address, [], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO r_lvl
      P.new(:subnet_mask, [], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO r_lvl
      P.new(:default_gateway, [], max: 1, write: true, r_lvl: 3, w_lvl: 2),
      # TODO shall contain the IP address of the DHCP/BootP server
      # TODO r_lvl
      P.new(:dhcp_bootp_server, [], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO r_lvl
      P.new(:mac_address, [mac_addr], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO r_lvl
      P.new(:system_setup_multicast_address, [0xE000170C],
        max: 1,
        write: false,
        r_lvl: 3,
        w_lvl: 0
      ),
      # TODO change of value shall only become acitive after reset of device
      # TODO r_lvl, w_lvl
      P.new(:routing_multicast_address, [0xE000170C], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # TODO r_lvl, w_lvl
      P.new(:ttl, [0x10], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # TODO r_lvl
      P.new(:knxnetip_device_capabilities, [0x3], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO if the value of the Property changes the current value shall be sent using M_PropInfo.ind
      # TODO r_lvl
      P.new(:knxnetip_device_state, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # the following properties only have to be implemented by devices providing Routing
      # P.new(:knxnetip_routing_capabilities, [], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # P.new(:priority_fifo_enabled, [], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # TODO r_lvl
      P.new(:queue_overflow_to_ip, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO r_lvl
      P.new(:queue_overflow_to_knx, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # the following properties only have to be implemented by devices providing Routing
      # P.new(:msg_transmit_to_ip, [], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      # P.new(:msg_transmit_to_knx, [], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # TODO write, r_lvl, w_lvl
      P.new(:friendly_name, [friendly_name], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      # valid value range: 20 - 100
      # TODO write, r_lvl, w_lvl
      P.new(:routing_busy_wait_time, [100], max: 1, write: true, r_lvl: 3, w_lvl: 2)
    ]
  end

  def convert_ip_to_number({e3, e2, e1, e0}) do
    (e3 <<< 24) + (e2 <<< 16) + (e1 <<< 8) + e0
  end
end
