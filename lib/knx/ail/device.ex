defmodule Knx.Ail.Device do
  alias Knx.Ail.Property, as: P

  def get_object_index(), do: 0

  # TODO Auth --- unklar, aber gehe davon aus, dass jeweils die Rechte auf dem IO ausschlaggebend sind
  #   auch wenn nicht direkt uber data-primitives zugegriffen wird

  def get_desc(props),
    do: P.read_prop_value(props, :pid_device_descriptor)

  def set_address(props, <<subnet_addr::8, device_addr::8>>) do
    props
    |> P.write_prop_value(:pid_subnet_addr, <<subnet_addr>>)
    |> P.write_prop_value(:pid_device_addr, <<device_addr>>)
  end

  def get_address(props) do
    subnet = P.read_prop_value(props, :pid_subnet_addr)
    device = P.read_prop_value(props, :pid_device_addr)
    <<addr::16>> = <<subnet::8, device::8>>
    addr
  end

  def prog_mode?(props),
    do: 1 == P.read_prop_value(props, :pid_prog_mode)

  def serial_matches?(props, other_serial) do
    other_serial == P.read_prop_value(props, :pid_serial)
  end

  def get_max_apdu_length(props),
    do: P.read_prop_value(props, :pid_max_apdu_length)

  def verify?(props) do
    %{verify_mode: verify_mode} = P.read_prop_value(props, :pid_device_control)
    verify_mode
  end

  @device_control %{
    safe_state: false,
    verify_mode: false,
    ia_duplication: false,
    user_stopped: false
  }
  def get_device_props(serial, order_info, hardware_type, subnet_addr \\ 0xFF) do
    [
      P.new(:pid_object_type, [0], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_load_state_control, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_serial, [serial], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_manufacturer_id, [0xAFFE], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_device_control, [@device_control], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_order_info, [order_info], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_version, [0x0001], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_routing_count, [3], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_prog_mode, [0], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_max_apdu_length, [15], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_subnet_addr, [subnet_addr], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_device_addr, [0xFF], max: 1, write: true, r_lvl: 3, w_lvl: 3),
      P.new(:pid_hardware_type, [hardware_type], max: 1, write: false, r_lvl: 3, w_lvl: 0),
      P.new(:pid_device_descriptor, [0x07B0], max: 1, write: false, r_lvl: 3, w_lvl: 0)
    ]
  end
end
