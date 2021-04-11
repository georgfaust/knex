defmodule MemTest do
  use ExUnit.Case

  alias Knx.Mem

  @mem <<0::64>>
  @table_size 4
  @table_data <<1::16, 2::16, 3::16, 4::16>>
  @table_mem <<0::24, @table_size::16, @table_data::bits>>

  test "mem" do
    assert {:ok, <<_::16, 0xDEAD::16, _::bytes>> = mem} = Mem.write(@mem, 2, <<0xDEAD::16>>)
    assert {:ok, <<0x00DE_AD00::32>>} = Mem.read(mem, 1, 4)
    assert {:ok, <<_::16, 0xDEAD_BEEF::32, _::bytes>> = mem} = Mem.write(mem, 4, <<0xBEEF::16>>)
    assert {:ok, <<0x0000_DEAD_BEEF_0000::64>>} = Mem.read(mem, 0, 8)
    # invalid memory write
    assert {:error, :area_invalid} = Mem.write(@mem, 8, <<0xFF::8>>)
    # partially invalid memory write
    assert {:error, :area_invalid} = Mem.write(@mem, 7, <<0xFFFF::16>>)
    # invalid memory read
    assert {:error, :area_invalid} = Mem.read(@mem, 8, 1)
    # partially invalid memory readmem_test
    assert {:error, :area_invalid} = Mem.read(@mem, 7, 2)
    # table
    assert {:ok, @table_size, @table_data} == Mem.read_table(@table_mem, 3, 2)
  end
end
