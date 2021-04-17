defmodule MemTest do
  use ExUnit.Case

  alias Knx.Mem
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @mem <<0::64>>
  @table_size 4
  @table_data <<1::16, 2::16, 3::16, 4::16>>
  @table_mem <<0::24, @table_size::16, @table_data::bits>>

  def mem_read(mem, number, addr) do
    case Mem.handle(
          {:mem, :ind, %F{apci: :mem_read, data: [number, addr]}},
          %S{mem: mem}
          ) do
      [{:al, :req, %F{apci: :mem_resp, data: [0, ^addr, <<>>]}}] ->
        {:error, :area_invalid}
      [{:al, :req, %F{apci: :mem_resp, data: [^number, ^addr, data]}}] ->
        data
    end
  end

  def mem_write(mem, addr, data) do
    number = byte_size(data)
    case Mem.handle(
            {:mem, :ind, %F{apci: :mem_write, data: [number, addr, data]}},
            %S{mem: mem}
          ) do
      [{:al, :req, %F{apci: :mem_resp, data: [0, ^addr, <<>>]}}] ->
        {:error, :area_invalid}
      {
        %S{mem: new_mem},
        [{:al, :req, %F{apci: :mem_resp, data: [^number, ^addr, ^data]}}]
      } ->
        new_mem
    end
  end

  describe "mem_read.ind and mem_write.ind" do
    test "successful write and read" do
      assert <<_::16, 0xDEAD::16, _::bytes>> = mem = mem_write(@mem, 2, <<0xDEAD::16>>)
      assert <<0x00DE_AD00::32>> = mem_read(mem, 4, 1)
      assert <<_::16, 0xDEAD_BEEF::32, _::bytes>> = mem = mem_write(mem, 4, <<0xBEEF::16>>)
      assert <<0x0000_DEAD_BEEF_0000::64>> = mem_read(mem, 8, 0)
    end

    test "invalid memory write" do
      assert {:error, :area_invalid} = mem_write(@mem, 8, <<0xFF::8>>)
    end

    test "partially invalid memory write" do
      assert {:error, :area_invalid} = mem_write(@mem, 7, <<0xFFFF::16>>)
    end

    test "invalid memory read" do
      assert {:error, :area_invalid} = mem_read(@mem, 1, 8)
    end

    test "partially invalid memory read" do
      assert {:error, :area_invalid} = mem_read(@mem, 2, 7)
    end
  end

  test "read_table" do
    assert {:ok, @table_size, @table_data} == Mem.read_table(@table_mem, 2, 3)
  end
end
