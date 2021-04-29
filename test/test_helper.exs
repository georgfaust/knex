ExUnit.start()

# :dbg.start()
# :dbg.tracer()
# :dbg.tpl(Knx.Stack.Tl, :handle, [{:_, [], [{:return_trace}]}])
# :dbg.p(:all, :call)

defmodule Helper do
  alias Knx.Ail.Property, as: P
  alias Knx.Ail.GroupObject, as: GO

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

  # IO
  @serial 0x112233445566
  @subnet_addr 0xFF
  @device_addr 0xFF
  @desc 0x07B0
  @device_control %{
    safe_state: false,
    verify_mode: false,
    ia_duplication: false,
    user_stopped: false
  }

  # ---

  def get_assoc_tab(), do: @assoc_tab
  def get_go_tab(), do: @go_tab
  def get_addr_tab(), do: @addr_tab

  # frames
  @hops 6

  def get_frame(src: src, dest: dest, addr_t: addr_t, data: data) do
    len = byte_size(data) - 1

    <<
      0b10::2,
      0b11::2,
      0::2,
      0::2,
      src::16,
      dest::16,
      addr_t::1,
      @hops::3,
      len::4,
      data::bits
    >>
  end

  def get_device_props(prog_mode, verify \\ false) do
    device_control = %{@device_control | verify_mode: verify}

    [
      P.new(:pid_object_type, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_load_state_control, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_serial, [@serial], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_manufacturer_id, [0xAFFE], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_device_control, [device_control], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_order_info, [0x0815], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_version, [0x0001], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_routing_count, [3], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_prog_mode, [prog_mode], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_max_apdu_length, [15], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_subnet_addr, [@subnet_addr], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_device_addr, [@device_addr], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_hardware_type, [0xAABBCCDDEEFF], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_device_descriptor, [@desc], max: 1, write: false, r_lvl: 3, w_lvl: 0)
    ]
  end

  def get_table_props(object_type, mem_ref) do
    [
      P.new(:pid_object_type, [object_type], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_load_state_control, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_table_reference, [mem_ref], max: 1, write: false, r_lvl: 3, w_lvl: 0)
      # Table                 23 = PID_TABLE      PDT_UNSIGNED_INT[]
      # Memory Control Table  27 = PID_MCB_TABLE  PDT_GENERIC_08[]
      # Error code            28 = PID_ERROR_CODE PDT_ENUM8
    ]
  end
end
