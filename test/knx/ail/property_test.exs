defmodule Knx.Ail.PropertyTest do
  use ExUnit.Case

  alias Knx.Ail.Property, as: P

  @pid1_atom :pid_channel_01_param
  @pid2_atom :pid_channel_02_param
  @pid1 101
  @pid2 102
  @ptd 0x11
  @pid_manufacturer_id 12
  @pid_device_control 14
  @pid_prog_mode 54

  @props_0 [
    P.new(@pid1_atom, [1, 2, 3], max: 5, write: true, r_lvl: 0, w_lvl: 0),
    P.new(@pid2_atom, [4, 5, 6], max: 5, write: true, r_lvl: 0, w_lvl: 0)
  ]
  @props_1 [
    P.new(@pid1_atom, [111], max: 1, write: true, r_lvl: 0, w_lvl: 0),
    P.new(@pid2_atom, [222], max: 1, write: true, r_lvl: 0, w_lvl: 0)
  ]

  test("get_prop") do
    assert {:ok, 0, @ptd, %{id: @pid1}} = P.get_prop(@props_0, @pid1)
    assert {:ok, 1, @ptd, %{id: @pid2}} = P.get_prop(@props_0, 0, 2)
    assert {:ok, 1, @ptd, %{id: @pid2}} = P.get_prop(@props_1, @pid2, 0)
    assert {:ok, 0, @ptd, %{id: @pid1}} = P.get_prop(@props_1, 0, 1)
    assert {:error, :prop_invalid} = P.get_prop(@props_0, :pid_non_existing)
    assert {:error, :prop_invalid} = P.get_prop(@props_0, 0, 99)
    assert {:error, :argument_error} = P.get_prop(@props_0, 0, 0)
  end

  test "read_prop" do
    assert {:ok, 1, <<3>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 1, start: 0)
    assert {:ok, 1, <<1>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 1, start: 1)

    assert {:ok, 1, <<1, 2, 3>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 3, start: 1)

    # TODO muss error sein!? --> standard
    assert {:ok, 1, <<1, 2, 3>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 4, start: 1)

    assert {:ok, 1, <<3>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 1, start: 3)
    assert {:error, :nothing_read} = P.read_prop(@props_0, 0, pid: @pid1, elems: 1, start: 4)
  end

  test "write_prop" do
    assert {:ok, [%{values: []}, _], _} =
             P.write_prop(@props_0, 0, pid: @pid1, elems: 1, start: 0, data: <<0>>)

    assert {:ok, [%{values: [1, 22, 3]}, _], _} =
             P.write_prop(@props_0, 0, pid: @pid1, elems: 1, start: 2, data: <<22>>)

    assert {:ok, [%{values: [11, 22, 33]}, _], _} =
             P.write_prop(@props_0, 0, pid: @pid1, elems: 3, start: 1, data: <<11, 22, 33>>)

    assert {:ok, [%{values: [1, 2, 3, 44, 55]}, _], _} =
             P.write_prop(@props_0, 0, pid: @pid1, elems: 2, start: 4, data: <<44, 55>>)

    assert {:error, :argument_error} =
             P.write_prop(@props_0, 0, pid: @pid1, elems: 2, start: 0, data: <<0, 0>>)

    assert {:error, :argument_error_data_length} =
             P.write_prop(@props_0, 0, pid: @pid1, elems: 2, start: 1, data: <<0>>)
  end

  @device_control %{
    safe_state: true,
    verify_mode: false,
    ia_duplication: true,
    user_stopped: false
  }

  test "encode" do
    assert <<1>> == P.encode(@pid_prog_mode, nil, 1)
    assert <<0b0000_1010>> == P.encode(@pid_device_control, nil, @device_control)
    assert <<1>> == P.encode(nil, :pdt_char, 1)
    assert <<0xFF>> == P.encode(nil, :pdt_char, -1)
    assert <<1>> == P.encode(nil, :pdt_unsigned_char, 1)
    assert <<0xFF>> == P.encode(nil, :pdt_unsigned_char, 0xFF)
    assert <<0x7FFF::16>> == P.encode(nil, :pdt_int, 0x7FFF)
    assert <<0xFFFF::16>> == P.encode(nil, :pdt_int, -1)
    assert <<0xFFFF::16>> == P.encode(nil, :pdt_unsigned_int, 0xFFFF)
    assert <<0x7FFF_FFFF::32>> == P.encode(nil, :pdt_long, 0x7FFF_FFFF)
    assert <<0xFFFF_FFFF::32>> == P.encode(nil, :pdt_long, -1)
    assert <<0xFFFF_FFFF::32>> == P.encode(nil, :pdt_unsigned_long, 0xFFFF_FFFF)
    # TODO assert <<>> == P.encode(nil, :pdt_knx_float, _), do: raise("TODO use DPT encode")
    assert <<0::32>> == P.encode(nil, :pdt_float, 0.0)
    assert <<63, 128, 0, 0>> == P.encode(nil, :pdt_float, 1.0)
    # assert <<>> == P.encode(nil, :pdt_time, _), do: raise("TODO use DPT encode")
    # assert <<>> == P.encode(nil, :pdt_date, _), do: raise("TODO use DPT encode")
    assert <<1::size(01)-unit(8)>> == P.encode(nil, :pdt_generic_01, 1)
    assert <<1::size(02)-unit(8)>> == P.encode(nil, :pdt_generic_02, 1)
    assert <<1::size(03)-unit(8)>> == P.encode(nil, :pdt_generic_03, 1)
    assert <<1::size(04)-unit(8)>> == P.encode(nil, :pdt_generic_04, 1)
    assert <<1::size(05)-unit(8)>> == P.encode(nil, :pdt_generic_05, 1)
    assert <<1::size(06)-unit(8)>> == P.encode(nil, :pdt_generic_06, 1)
    assert <<1::size(07)-unit(8)>> == P.encode(nil, :pdt_generic_07, 1)
    assert <<1::size(08)-unit(8)>> == P.encode(nil, :pdt_generic_08, 1)
    assert <<1::size(09)-unit(8)>> == P.encode(nil, :pdt_generic_09, 1)
    assert <<1::size(10)-unit(8)>> == P.encode(nil, :pdt_generic_10, 1)
    assert <<1::size(11)-unit(8)>> == P.encode(nil, :pdt_generic_11, 1)
    assert <<1::size(12)-unit(8)>> == P.encode(nil, :pdt_generic_12, 1)
    assert <<1::size(13)-unit(8)>> == P.encode(nil, :pdt_generic_13, 1)
    assert <<1::size(14)-unit(8)>> == P.encode(nil, :pdt_generic_14, 1)
    assert <<1::size(15)-unit(8)>> == P.encode(nil, :pdt_generic_15, 1)
    assert <<1::size(16)-unit(8)>> == P.encode(nil, :pdt_generic_16, 1)
    assert <<1::size(17)-unit(8)>> == P.encode(nil, :pdt_generic_17, 1)
    assert <<1::size(18)-unit(8)>> == P.encode(nil, :pdt_generic_18, 1)
    assert <<1::size(19)-unit(8)>> == P.encode(nil, :pdt_generic_19, 1)
    assert <<1::size(20)-unit(8)>> == P.encode(nil, :pdt_generic_20, 1)
  end

  test "decode" do
    assert 1 == P.decode(@pid_prog_mode, nil, <<1>>)
    assert @device_control = P.decode(@pid_device_control, nil, <<0b0000_1010>>)
    assert 1 == P.decode(nil, :pdt_char, <<1>>)
    assert -1 == P.decode(nil, :pdt_char, <<0xFF>>)
    assert 1 == P.decode(nil, :pdt_unsigned_char, <<1>>)
    assert 1 == P.decode(nil, :pdt_int, <<1::16>>)
    assert -1 == P.decode(nil, :pdt_int, <<0xFFFF::16>>)
    assert 1 == P.decode(nil, :pdt_unsigned_int, <<1::16>>)
    assert 1 == P.decode(nil, :pdt_long, <<1::32>>)
    assert -1 == P.decode(nil, :pdt_long, <<0xFFFF_FFFF::32>>)
    assert 1 == P.decode(nil, :pdt_unsigned_long, <<1::32>>)
    # TODO assert 0 = P.decode(nil, :pdt_knx_float, _)
    assert 0.0 == P.decode(nil, :pdt_float, <<0::32>>)
    assert 1.0 == P.decode(nil, :pdt_float, <<63, 128, 0, 0>>)
    # TODO assert 0 = P.decode(nil, :pdt_time, _)
    # TODO assert 0 = P.decode(nil, :pdt_date, _)
    assert 1 == P.decode(nil, :pdt_generic_01, <<1::size(01)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_02, <<1::size(02)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_03, <<1::size(03)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_04, <<1::size(04)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_05, <<1::size(05)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_06, <<1::size(06)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_07, <<1::size(07)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_08, <<1::size(08)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_09, <<1::size(09)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_10, <<1::size(10)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_11, <<1::size(11)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_12, <<1::size(12)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_13, <<1::size(13)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_14, <<1::size(14)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_15, <<1::size(15)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_16, <<1::size(16)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_17, <<1::size(17)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_18, <<1::size(18)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_19, <<1::size(19)-unit(8)>>)
    assert 1 == P.decode(nil, :pdt_generic_20, <<1::size(20)-unit(8)>>)
  end

  test "lists" do
    assert <<0, 0, 0, 1, 255, 255>> ==
             P.encode_list(@pid_manufacturer_id, :pdt_unsigned_int, [0, 1, 0xFFFF])

    assert [0, 1, 0xFFFF] ==
             P.decode_into_list(@pid_manufacturer_id, :pdt_unsigned_int, <<0, 0, 0, 1, 255, 255>>)
  end
end
