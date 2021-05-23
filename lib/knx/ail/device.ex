defmodule Knx.Ail.Device do
  alias Knx.Ail.Property, as: P
  import Knx.Defs
  require Knx.Defs
  use Bitwise

  # TODO Auth --- unklar, aber gehe davon aus, dass jeweils die Rechte auf dem IO ausschlaggebend sind
  #   auch wenn nicht direkt uber data-primitives zugegriffen wird

  def get_desc(props),
    do: P.read_prop_value(props, :device_descriptor)

  def set_address(props, address) do
    <<subnet_addr::8, device_addr::8>> = <<address::16>>

    props
    |> P.write_prop_value(:subnet_addr, <<subnet_addr>>)
    |> P.write_prop_value(:device_addr, <<device_addr>>)
  end

  def get_address(props) do
    subnet = P.read_prop_value(props, :subnet_addr)
    device = P.read_prop_value(props, :device_addr)
    <<addr::16>> = <<subnet::8, device::8>>
    addr
  end

  def prog_mode?(props),
    do: 1 == P.read_prop_value(props, :prog_mode)

  def set_prog_mode(props, prog_mode),
    do: P.write_prop_value(props, :prog_mode, <<0::7, prog_mode::1>>)

  def get_prog_mode(props),
    do: P.read_prop_value(props, :prog_mode)

  def serial_matches?(props, other_serial) do
    other_serial == P.read_prop_value(props, :serial)
  end

  def get_max_apdu_length(props),
    do: P.read_prop_value(props, :max_apdu_length)

  def verify?(props) do
    %{verify_mode: verify_mode} = P.read_prop_value(props, :device_ctrl)
    verify_mode
  end

  def update_device_ctrl(props, update) do
    device_ctrl = P.read_prop_value(props, :device_ctrl)
    device_ctrl = Map.merge(device_ctrl, update)
    P.write_prop_value(props, :device_ctrl, device_ctrl)
  end

  @device_ctrl %{
    safe_state: false,
    verify_mode: false,
    ia_duplication: false,
    user_stopped: false
  }
  def get_device_props(serial, order_info, hardware_type, addr \\ 0xFFFF) do

    device_addr = addr &&& 0x00FF
    subnet_addr = (addr &&& 0xFF00) >>> 8

    [
      P.new(:object_type, [object_type(:device)], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:load_state_ctrl, [load_state(:unloaded)], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:serial, [serial], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:manu_id, [0xAFFE], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:device_ctrl, [@device_ctrl], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:order_info, [order_info], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:version, [0x0001], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:routing_count, [3], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:prog_mode, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:max_apdu_length, [15], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:subnet_addr, [subnet_addr], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:device_addr, [device_addr], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:hw_type, [hardware_type], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:device_descriptor, [0x07B0], max: 1, write: false, r_lvl: 3, w_lvl: 0)
    ]
  end
end
