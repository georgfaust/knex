defmodule Knx.Ail.PropertyTest do
  use ExUnit.Case

  alias Knx.Ail.Property, as: P
  import Knx.Defs
  require Knx.Defs

  @pid1_atom :channel_01_param
  @pid2_atom :channel_02_param
  @pid1 101
  @pid2 102
  @ptd 0x11

  @access_level_all 0
  @interface_prog_o_idx 5

  # @noop 0
  @start_loading 1
  @load_completed 2
  # @additional_lc 3
  @unload 4

  # @alc_data_rel_alloc 0xB

  @props_0 [
    P.new(@pid1_atom, [1, 2, 3], max: 5, write: true, r_lvl: 0, w_lvl: 0),
    P.new(@pid2_atom, [4, 5, 6], max: 5, write: true, r_lvl: 0, w_lvl: 0)
  ]
  @props_1 [
    P.new(@pid1_atom, [111], max: 1, write: true, r_lvl: 0, w_lvl: 0),
    P.new(@pid2_atom, [222], max: 1, write: true, r_lvl: 0, w_lvl: 0)
  ]
  @props_addr_tab [
    # TODO noch nicht fertig
    P.new(:load_state_ctrl, [load_state(:unloaded)], max: 1, write: true, r_lvl: 0, w_lvl: 0)
  ]

  describe "load controls" do
    @interface_prog_props Knx.Ail.InterfaceProg.get_props(0, 1)
    @tag :current
    test "unload interface prog (this is the first load control ETS calls)" do
      Cache.start_link(%{
        objects: [interface_prog: nil],
        mem: <<1>>
      })

      assert {:ok, _props, %{values: [load_state(:unloaded)]}, _} =
               P.write_prop(
                 @interface_prog_o_idx,
                 @interface_prog_props,
                 @access_level_all,
                 pid: prop_id(:load_state_ctrl),
                 elems: 1,
                 start: 1,
                 data: <<@unload::8, 0::unit(8)-9>>
               )
    end

    @addr_tab_mem_ref 4
    test "load address table" do
      Cache.start_link(%{
        objects: [addr_tab: Helper.get_table_props(1, @addr_tab_mem_ref)],
        mem:
          <<0::unit(8)-size(@addr_tab_mem_ref), 5::16, 10::16, 20::16, 30::16, 40::16, 50::16,
            0::800>>
      })

      assert {:ok, props, %{values: [load_state(:loading)]}, _} =
               P.write_prop(1, @props_addr_tab, 0,
                 pid: prop_id(:load_state_ctrl),
                 elems: 1,
                 start: 1,
                 data: <<@start_loading::8, 0::unit(8)-9>>
               )

      # TODO not implemented
      # rel_alloc = Knx.Ail.Lsm.encode_le(:alc_data_rel_alloc, [10, 1, 0xFF])

      # assert {:ok, _, %{values: [load_state(:loading)]}} =
      #          P.write_prop(1, props, 0,
      #            pid: prop_id(:load_state_ctrl),
      #            elems: 1,
      #            start: 1,
      #            data: rel_alloc
      #          )

      assert {:ok, _, %{values: [load_state(:loaded)]}, _} =
               P.write_prop(1, props, 0,
                 pid: prop_id(:load_state_ctrl),
                 elems: 1,
                 start: 1,
                 data: <<@load_completed::8, 0::unit(8)-9>>
               )

      assert [-1, 10, 20, 30, 40, 50] == Cache.get(:addr_tab)
    end
  end

  test("get_prop") do
    assert {:ok, 0, @ptd, %{id: @pid1}} = P.get_prop(@props_0, @pid1)
    assert {:ok, 1, @ptd, %{id: @pid2}} = P.get_prop(@props_0, 0, 1)
    assert {:ok, 1, @ptd, %{id: @pid2}} = P.get_prop(@props_1, @pid2, 0)
    assert {:ok, 0, @ptd, %{id: @pid1}} = P.get_prop(@props_1, 0, 0)
    assert {:error, :prop_invalid} = P.get_prop(@props_0, :non_existing)
    assert {:error, :prop_invalid} = P.get_prop(@props_0, 0, 99)
  end

  test "read_prop" do
    assert {:ok, 0, <<3>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 1, start: 0)
    assert {:ok, 0, <<1>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 1, start: 1)

    assert {:ok, 0, <<1, 2, 3>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 3, start: 1)

    # TODO muss error sein!? --> standard
    assert {:ok, 0, <<1, 2, 3>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 4, start: 1)

    assert {:ok, 0, <<3>>} = P.read_prop(@props_0, 0, pid: @pid1, elems: 1, start: 3)
    assert {:error, :nothing_read} = P.read_prop(@props_0, 0, pid: @pid1, elems: 1, start: 4)
  end

  test "write_prop" do
    assert {:ok, [%{values: []}, _], _, _} =
             P.write_prop(nil, @props_0, 0, pid: @pid1, elems: 1, start: 0, data: <<0>>)

    assert {:ok, [%{values: [1, 22, 3]}, _], _, _} =
             P.write_prop(nil, @props_0, 0, pid: @pid1, elems: 1, start: 2, data: <<22>>)

    assert {:ok, [%{values: [11, 22, 33]}, _], _, _} =
             P.write_prop(nil, @props_0, 0, pid: @pid1, elems: 3, start: 1, data: <<11, 22, 33>>)

    assert {:ok, [%{values: [1, 2, 3, 44, 55]}, _], _, _} =
             P.write_prop(nil, @props_0, 0, pid: @pid1, elems: 2, start: 4, data: <<44, 55>>)

    assert {:error, :argument_error} =
             P.write_prop(nil, @props_0, 0, pid: @pid1, elems: 2, start: 0, data: <<0, 0>>)

    assert {:error, :argument_error_data_length, _} =
             P.write_prop(nil, @props_0, 0, pid: @pid1, elems: 2, start: 1, data: <<0>>)
  end

  @device_ctrl %{
    safe_state: true,
    verify_mode: false,
    ia_duplication: true,
    user_stopped: false
  }

  test "encode" do
    assert <<1>> == P.encode(prop_id(:prog_mode), nil, 1)
    assert <<0b0000_1010>> == P.encode(prop_id(:device_ctrl), nil, @device_ctrl)
    assert <<1>> == P.encode(nil, :char, 1)
    assert <<0xFF>> == P.encode(nil, :char, -1)
    assert <<1>> == P.encode(nil, :unsigned_char, 1)
    assert <<0xFF>> == P.encode(nil, :unsigned_char, 0xFF)
    assert <<0x7FFF::16>> == P.encode(nil, :int, 0x7FFF)
    assert <<0xFFFF::16>> == P.encode(nil, :int, -1)
    assert <<0xFFFF::16>> == P.encode(nil, :unsigned_int, 0xFFFF)
    assert <<0x7FFF_FFFF::32>> == P.encode(nil, :long, 0x7FFF_FFFF)
    assert <<0xFFFF_FFFF::32>> == P.encode(nil, :long, -1)
    assert <<0xFFFF_FFFF::32>> == P.encode(nil, :unsigned_long, 0xFFFF_FFFF)
    # TODO assert <<>> == P.encode(nil, :knx_float, _), do: raise("TODO use DPT encode")
    assert <<0::32>> == P.encode(nil, :float, 0.0)
    assert <<63, 128, 0, 0>> == P.encode(nil, :float, 1.0)
    # assert <<>> == P.encode(nil, :time, _), do: raise("TODO use DPT encode")
    # assert <<>> == P.encode(nil, :date, _), do: raise("TODO use DPT encode")
    assert <<1::size(01)-unit(8)>> == P.encode(nil, :generic_01, 1)
    assert <<1::size(02)-unit(8)>> == P.encode(nil, :generic_02, 1)
    assert <<1::size(03)-unit(8)>> == P.encode(nil, :generic_03, 1)
    assert <<1::size(04)-unit(8)>> == P.encode(nil, :generic_04, 1)
    assert <<1::size(05)-unit(8)>> == P.encode(nil, :generic_05, 1)
    assert <<1::size(06)-unit(8)>> == P.encode(nil, :generic_06, 1)
    assert <<1::size(07)-unit(8)>> == P.encode(nil, :generic_07, 1)
    assert <<1::size(08)-unit(8)>> == P.encode(nil, :generic_08, 1)
    assert <<1::size(09)-unit(8)>> == P.encode(nil, :generic_09, 1)
    assert <<1::size(10)-unit(8)>> == P.encode(nil, :generic_10, 1)
    assert <<1::size(11)-unit(8)>> == P.encode(nil, :generic_11, 1)
    assert <<1::size(12)-unit(8)>> == P.encode(nil, :generic_12, 1)
    assert <<1::size(13)-unit(8)>> == P.encode(nil, :generic_13, 1)
    assert <<1::size(14)-unit(8)>> == P.encode(nil, :generic_14, 1)
    assert <<1::size(15)-unit(8)>> == P.encode(nil, :generic_15, 1)
    assert <<1::size(16)-unit(8)>> == P.encode(nil, :generic_16, 1)
    assert <<1::size(17)-unit(8)>> == P.encode(nil, :generic_17, 1)
    assert <<1::size(18)-unit(8)>> == P.encode(nil, :generic_18, 1)
    assert <<1::size(19)-unit(8)>> == P.encode(nil, :generic_19, 1)
    assert <<1::size(20)-unit(8)>> == P.encode(nil, :generic_20, 1)
  end

  test "decode" do
    assert 1 == P.decode(prop_id(:prog_mode), nil, <<1>>)
    assert @device_ctrl = P.decode(prop_id(:device_ctrl), nil, <<0b0000_1010>>)
    assert 1 == P.decode(nil, :char, <<1>>)
    assert -1 == P.decode(nil, :char, <<0xFF>>)
    assert 1 == P.decode(nil, :unsigned_char, <<1>>)
    assert 1 == P.decode(nil, :int, <<1::16>>)
    assert -1 == P.decode(nil, :int, <<0xFFFF::16>>)
    assert 1 == P.decode(nil, :unsigned_int, <<1::16>>)
    assert 1 == P.decode(nil, :long, <<1::32>>)
    assert -1 == P.decode(nil, :long, <<0xFFFF_FFFF::32>>)
    assert 1 == P.decode(nil, :unsigned_long, <<1::32>>)
    # TODO assert 0 = P.decode(nil, :knx_float, _)
    assert 0.0 == P.decode(nil, :float, <<0::32>>)
    assert 1.0 == P.decode(nil, :float, <<63, 128, 0, 0>>)
    # TODO assert 0 = P.decode(nil, :time, _)
    # TODO assert 0 = P.decode(nil, :date, _)
    assert 1 == P.decode(nil, :generic_01, <<1::size(01)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_02, <<1::size(02)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_03, <<1::size(03)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_04, <<1::size(04)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_05, <<1::size(05)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_06, <<1::size(06)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_07, <<1::size(07)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_08, <<1::size(08)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_09, <<1::size(09)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_10, <<1::size(10)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_11, <<1::size(11)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_12, <<1::size(12)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_13, <<1::size(13)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_14, <<1::size(14)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_15, <<1::size(15)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_16, <<1::size(16)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_17, <<1::size(17)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_18, <<1::size(18)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_19, <<1::size(19)-unit(8)>>)
    assert 1 == P.decode(nil, :generic_20, <<1::size(20)-unit(8)>>)
  end

  test "lists" do
    assert <<0, 0, 0, 1, 255, 255>> ==
             P.encode_list(prop_id(:manu_id), :unsigned_int, [0, 1, 0xFFFF])

    assert [0, 1, 0xFFFF] ==
             P.decode_into_list(prop_id(:manu_id), :unsigned_int, <<0, 0, 0, 1, 255, 255>>)
  end
end
