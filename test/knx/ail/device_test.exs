defmodule Knx.Ail.DeviceTest do
  use ExUnit.Case

  alias Knx.Ail.Device
  alias Knx.Ail.Property, as: P

  @serial 0x112233445566
  @other_serial 0x1122334455FF
  @desc 0x07B0
  @new_subnet_addr 0x08
  @new_device_addr 0x15
  @new_ind_addr <<@new_subnet_addr, @new_device_addr>>

  @device_props Helper.get_device_props(1)

  test "get_max_apdu_length" do
    assert <<0, 15>> == Device.get_max_apdu_length(@device_props)
  end

  test "verify?" do
    no_verify_props = Helper.get_device_props(1, false)
    assert false == Device.verify?(no_verify_props)
    verify_props = Helper.get_device_props(1, true)
    assert true == Device.verify?(verify_props)
  end

  test "get_desc" do
    assert <<@desc::16>> == Device.get_desc(@device_props)
  end

  test "prog_mode?" do
    assert true == Device.prog_mode?(@device_props)
  end

  test "serial_matches?" do
    assert true == Device.serial_matches?(@device_props, @serial)
    assert false == Device.serial_matches?(@device_props, @other_serial)
  end

  test "set_address" do
    props = Device.set_address(@device_props, @new_ind_addr)
    assert <<@new_subnet_addr>> == P.read_prop_value(props, :pid_subnet_addr)
    assert <<@new_device_addr>> == P.read_prop_value(props, :pid_device_addr)
  end
end
