defmodule Knx.Stack.AlTest do
  use ExUnit.Case

  alias Knx.Stack.Al
  alias Knx.Frame, as: F

  @group_read 0b0000_000000
  @group_resp 0b0001
  @group_write 0b0010

  @ind_addr_write 0b0011_000000
  @ind_addr_read 0b0100_000000
  @ind_addr_resp 0b0101_000000

  @adc_read 0b0110
  @adc_resp 0b0111

  @sys_nw_param_read 0b0111_001000
  @sys_nw_param_resp 0b0111_001001
  @sys_nw_param_write 0b0111_001010

  # NOTE: in the APCI table mem_X have 6 bit,
  #   in the pdu desc they have 4 bits.
  #   using 4 bits.
  @mem_read 0b1000
  @mem_resp 0b1001
  @mem_write 0b1010

  @user_mem_read 0b1011_000000
  @user_mem_resp 0b1011_000001
  @user_mem_write 0b1011_000010

  # not for future use
  @user_mem_bit_write 0b1011_000100

  @user_manu_info_read 0b1011_000101
  @user_manu_info_resp 0b1011_000110

  # TODO
  # @fun_prop_command 0b1011_000111
  # @fun_prop_state_read 0b1011_001000
  # @fun_prop_state_resp 0b1011_001001

  # 0b1011_001010 - 0b1011_110111 -- reserved USERMSG
  # 0b1011_111000 - 0b1011_111110 -- manufacturer specific area for USERMSG

  @device_desc_read 0b1100
  @device_desc_resp 0b1101

  # TODO
  # NOTE. in APCI table this is 0b1110_000000 but lower 6 bits of the restart-APCI are variable!
  # @restart 0b1110

  # coupler specific services - all not for future use

  # not for future use
  @mem_bit_write 0b1111_010000

  @auth_req 0b1111_010001
  @auth_resp 0b1111_010010
  @key_write 0b1111_010011
  @key_resp 0b1111_010100

  @prop_read 0b1111_010101
  @prop_resp 0b1111_010110
  @prop_write 0b1111_010111
  @prop_desc_read 0b1111_011000
  @prop_desc_resp 0b1111_011001

  @nw_param_read 0b1111_011010
  @nw_param_resp 0b1111_011011

  @ind_addr_serial_read 0b1111_011100
  @ind_addr_serial_resp 0b1111_011101
  @ind_addr_serial_write 0b1111_011110

  # open media specific services

  @nw_param_write 0b1111_100100

  @allowed_t_services %{
    group_read: [:t_data_group],
    group_resp: [:t_data_group],
    group_write: [:t_data_group],
    ind_addr_write: [:t_data_broadcast],
    ind_addr_read: [:t_data_broadcast],
    ind_addr_resp: [:t_data_broadcast],
    adc_read: [:t_data_con],
    adc_resp: [:t_data_con],
    sys_nw_param_read: [:t_data_sys_broadcast],
    sys_nw_param_resp: [:t_data_sys_broadcast],
    sys_nw_param_write: [:t_data_sys_broadcast],
    mem_read: [:t_data_individual, :t_data_con],
    mem_resp: [:t_data_individual, :t_data_con],
    mem_write: [:t_data_individual, :t_data_con],
    user_mem_read: [:t_data_con],
    user_mem_resp: [:t_data_con],
    user_mem_write: [:t_data_con],
    user_mem_bit_write: [:t_data_con],
    user_manu_info_read: [:t_data_con],
    user_manu_info_resp: [:t_data_con],
    fun_prop_command: [:t_data_individual, :t_data_con],
    fun_prop_state_read: [:t_data_individual, :t_data_con],
    fun_prop_state_resp: [:t_data_individual, :t_data_con],
    device_desc_read: [:t_data_individual, :t_data_con],
    device_desc_resp: [:t_data_individual, :t_data_con],
    restart: [:t_data_individual, :t_data_con],
    mem_bit_write: [:t_data_con],
    auth_req: [:t_data_con],
    auth_resp: [:t_data_con],
    key_write: [:t_data_con],
    key_resp: [:t_data_con],
    prop_read: [:t_data_individual, :t_data_con],
    prop_resp: [:t_data_individual, :t_data_con],
    prop_write: [:t_data_individual, :t_data_con],
    prop_desc_read: [:t_data_individual, :t_data_con],
    prop_desc_resp: [:t_data_individual, :t_data_con],
    nw_param_read: [:t_data_individual],
    nw_param_resp: [:t_data_broadcast, :t_data_individual],
    nw_param_write: [:t_data_individual],
    ind_addr_serial_write: [:t_data_broadcast],
    ind_addr_serial_read: [:t_data_broadcast],
    ind_addr_serial_resp: [:t_data_broadcast]
  }

  # --- /end Table 1

  # def roundtrip(_, apdu) do
  #   {_, apci, data} = Al.decode(apdu)
  #   assert {:ok, apdu} == Al.encode(apci, data)
  # end

  def roundtrip(apci, apdu) do
    service = hd(@allowed_t_services[apci])

    assert [{_, :ind, %{apci: ^apci, data: data}}] =
             Al.handle({:al, :ind, %F{data: apdu, service: service}}, nil)

    assert [{:tlsm, :req, %F{apci: ^apci, data: ^apdu}}] =
             Al.handle({:al, :req, %F{data: data, apci: apci, service: service}}, nil)
  end

  test "roundtrip" do
    roundtrip(:group_read, <<@group_read::10>>)
    roundtrip(:group_resp, <<@group_resp::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::32>>)
    roundtrip(:group_write, <<@group_write::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::32>>)
    roundtrip(:ind_addr_write, <<@ind_addr_write::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::16>>)
    roundtrip(:ind_addr_read, <<@ind_addr_read::10>>)
    roundtrip(:ind_addr_resp, <<@ind_addr_resp::10>>)
    roundtrip(:adc_read, <<@adc_read::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::14>>)
    roundtrip(:adc_resp, <<@adc_resp::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>)
    roundtrip(:sys_nw_param_read, <<@sys_nw_param_read::10, 0xAFFE_AFF0_AF::40>>)
    roundtrip(:sys_nw_param_resp, <<@sys_nw_param_resp::10, 0xAFFE_AFF0_AFFE_AFFE::64>>)
    roundtrip(:sys_nw_param_write, <<@sys_nw_param_write::10, 0xAFFE_AFF0_AFFE_AFFE::64>>)
    roundtrip(:mem_read, <<@mem_read::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::22>>)
    roundtrip(:mem_resp, <<@mem_resp::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>)
    roundtrip(:mem_write, <<@mem_write::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>)
    roundtrip(:user_mem_read, <<@user_mem_read::10, 0x0FFE_AF::24>>)
    roundtrip(:user_mem_resp, <<@user_mem_resp::10, 0x0FFE_AFFE::32>>)
    roundtrip(:user_mem_write, <<@user_mem_write::10, 0x0FFE_AFFE_AFFE_AFFE::64>>)
    roundtrip(:user_mem_bit_write, <<@user_mem_bit_write::10, 0xAFFE_AFFE::32>>)
    roundtrip(:user_manu_info_read, <<@user_manu_info_read::10>>)
    roundtrip(:user_manu_info_resp, <<@user_manu_info_resp::10, 0xAFFE_AFFE::24>>)
    # roundtrip(:fun_prop_command, <<@fun_prop_command::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    # roundtrip(:fun_prop_state_read, <<@fun_prop_state_read::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    # roundtrip(:fun_prop_state_resp, <<@fun_prop_state_resp::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    roundtrip(:device_desc_read, <<@device_desc_read::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::6>>)
    roundtrip(:device_desc_resp, <<@device_desc_resp::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>)
    # roundtrip(:restart, <<@restart::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::6>>)
    # roundtrip(:restart, <<@restart::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::22>>)
    # roundtrip(:restart, <<@restart::4, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::30>>)
    roundtrip(:mem_bit_write, <<@mem_bit_write::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    roundtrip(:auth_req, <<@auth_req::10, 0x00FE_AFFE_AF::40>>)
    roundtrip(:auth_resp, <<@auth_resp::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::8>>)
    roundtrip(:key_write, <<@key_write::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::40>>)
    roundtrip(:key_resp, <<@key_resp::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::8>>)
    roundtrip(:prop_read, <<@prop_read::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::32>>)
    roundtrip(:prop_resp, <<@prop_resp::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    roundtrip(:prop_write, <<@prop_write::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    roundtrip(:prop_desc_read, <<@prop_desc_read::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::24>>)
    roundtrip(:prop_desc_resp, <<@prop_desc_resp::10, 0xAFFE_AF00_00FE_AF::56>>)
    roundtrip(:nw_param_read, <<@nw_param_read::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    roundtrip(:nw_param_resp, <<@nw_param_resp::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)
    roundtrip(:nw_param_write, <<@nw_param_write::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::80>>)

    roundtrip(
      :ind_addr_serial_write,
      <<@ind_addr_serial_write::10, 0xAFFE_AFFE_AFFE_AFFE_0000_0000::96>>
    )

    roundtrip(
      :ind_addr_serial_read,
      <<@ind_addr_serial_read::10, 0xAFFE_AFFE_AFFE_AFFE_AFFE_AFFE::48>>
    )

    roundtrip(
      :ind_addr_serial_resp,
      <<@ind_addr_serial_resp::10, 0xAFFE_AFFE_AFFE_AFFE_0000::80>>
    )
  end
end
