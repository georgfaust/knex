defmodule Knx.Stack.AlTest do
  use ExUnit.Case
  require Knx.Defs
  import Knx.Defs

  alias Knx.Stack.Al
  alias Knx.Frame, as: F

  def roundtrip(apci, apdu) do
    service = Knx.Stack.Al.get_default_service(apci)

    assert [{_, :ind, %{apci: ^apci, data: data}}] =
             Al.handle({:al, :ind, %F{data: apdu, service: service}}, nil)

    assert [{:tlsm, :req, %F{apci: ^apci, data: ^apdu}}] =
             Al.handle({:al, :req, %F{data: data, apci: apci, service: service}}, nil)
  end

  test "roundtrip" do
    roundtrip(:group_read, <<apci(:group_read)::bits>>)
    roundtrip(:group_resp, <<apci(:group_resp)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::32>>)
    roundtrip(:group_write, <<apci(:group_write)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::32>>)

    roundtrip(
      :ind_addr_write,
      <<apci(:ind_addr_write)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::16>>
    )

    roundtrip(:ind_addr_read, <<apci(:ind_addr_read)::bits>>)
    roundtrip(:ind_addr_resp, <<apci(:ind_addr_resp)::bits>>)
    roundtrip(:mem_read, <<apci(:mem_read)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::22>>)
    roundtrip(:mem_resp, <<apci(:mem_resp)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>)
    roundtrip(:mem_write, <<apci(:mem_write)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>)
    roundtrip(:user_mem_read, <<apci(:user_mem_read)::bits, 0x0FFE_AF::24>>)
    roundtrip(:user_mem_resp, <<apci(:user_mem_resp)::bits, 0x0FFE_AFFE::32>>)
    roundtrip(:user_mem_write, <<apci(:user_mem_write)::bits, 0x0FFE_AFFE_AFFE_AFFE::64>>)
    roundtrip(:user_manu_info_read, <<apci(:user_manu_info_read)::bits>>)
    roundtrip(:user_manu_info_resp, <<apci(:user_manu_info_resp)::bits, 0xAFFE_AFFE::24>>)

    # roundtrip(:fun_prop_command, <<apci(:fun_prop_command)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    # roundtrip(:fun_prop_state_read, <<apci(:fun_prop_state_read)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    # roundtrip(:fun_prop_state_resp, <<apci(:fun_prop_state_resp)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    roundtrip(
      :device_desc_read,
      <<apci(:device_desc_read)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::6>>
    )

    roundtrip(
      :device_desc_resp,
      <<apci(:device_desc_resp)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>
    )

    # roundtrip(:restart, <<apci(:restart)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::6>>)
    # roundtrip(:restart, <<apci(:restart)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::22>>)
    # roundtrip(:restart, <<apci(:restart)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>)
    roundtrip(:auth_req, <<apci(:auth_req)::bits, 0x00FE_AFFE_AF::40>>)
    roundtrip(:auth_resp, <<apci(:auth_resp)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::8>>)
    roundtrip(:key_write, <<apci(:key_write)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::40>>)
    roundtrip(:key_resp, <<apci(:key_resp)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::8>>)
    roundtrip(:prop_read, <<apci(:prop_read)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::32>>)
    roundtrip(:prop_resp, <<apci(:prop_resp)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    roundtrip(:prop_write, <<apci(:prop_write)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)

    roundtrip(
      :prop_desc_read,
      <<apci(:prop_desc_read)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::24>>
    )

    roundtrip(:prop_desc_resp, <<apci(:prop_desc_resp)::bits, 0xAFFE_AF00_00FE_AF::56>>)

    roundtrip(
      :ind_addr_serial_write,
      <<apci(:ind_addr_serial_write)::bits, 0xAFFE_AFFE_AFFE_AFFE_0000_0000::96>>
    )

    roundtrip(
      :ind_addr_serial_read,
      <<apci(:ind_addr_serial_read)::bits, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::48>>
    )

    roundtrip(
      :ind_addr_serial_resp,
      <<apci(:ind_addr_serial_resp)::bits, 0xAFFE_AFFE_AFFE_AFFE_0000::80>>
    )
  end
end
