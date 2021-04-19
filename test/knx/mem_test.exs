defmodule MemTest do
  use ExUnit.Case

  alias Knx.Mem
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @mem1 <<0::64>>
  @mem2 <<0::128>>
  @table_size 4
  @table_data <<1::16, 2::16, 3::16, 4::16>>
  @table_mem <<0::24, @table_size::16, @table_data::bits>>

  # verify mode: active, max_apdu_length: 15
  @objects_verified %{0 => Helper.get_device_props(1, true)}
  # verify mode: inactive, max_apdu_length: 15
  @objects_unverified %{0 => Helper.get_device_props(1, false)}

  def mem_read(mem, objects, number, addr) do
    case Mem.handle(
          {:mem, :ind, %F{apci: :mem_read, data: [number, addr]}},
          %S{mem: mem, objects: objects}
          ) do
      [] -> {:error, :max_apdu_exceeded}
      [{:al, :req, %F{apci: :mem_resp, data: [0, ^addr, <<>>]}}] ->
        {:error, :area_invalid}
      [{:al, :req, %F{apci: :mem_resp, data: [^number, ^addr, data]}}] ->
        data
    end
  end

  def mem_write(mem, objects, addr, data) do
    number = byte_size(data)
    case Mem.handle(
            {:mem, :ind, %F{apci: :mem_write, data: [number, addr, data]}},
            %S{mem: mem, objects: objects}
          ) do
      [] -> {:error, :max_apdu_exceeded_or_no_verify}
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
      assert <<_::16, 0xDEAD::16, _::bytes>>
        = mem1 = mem_write(@mem1, @objects_verified, 2, <<0xDEAD::16>>)
      assert <<0x00DE_AD00::32>> = mem_read(mem1, @objects_verified, 4, 1)
      assert <<_::16, 0xDEAD_BEEF::32, _::bytes>>
        = mem1 = mem_write(mem1, @objects_verified, 4, <<0xBEEF::16>>)
      assert <<0x0000_DEAD_BEEF_0000::64>> = mem_read(mem1, @objects_verified, 8, 0)
    end

    test "invalid memory write" do
      assert {:error, :area_invalid} = mem_write(@mem1, @objects_verified, 8, <<0xFF::8>>)
    end

    test "partially invalid memory write" do
      assert {:error, :area_invalid} = mem_write(@mem1, @objects_verified, 7, <<0xFFFF::16>>)
    end

    test "memory write exceeds max apdu length" do
      assert {:error, :max_apdu_exceeded_or_no_verify}
        = mem_write(@mem2, @objects_verified, 1, <<1::112>>)
    end

    test "memory write with inactive verify mode" do
      assert {:error, :max_apdu_exceeded_or_no_verify}
        = mem_write(@mem1, @objects_unverified, 1, <<0xFF::8>>)
    end

    test "invalid memory read" do
      assert {:error, :area_invalid} = mem_read(@mem1, @objects_verified, 1, 8)
    end

    test "partially invalid memory read" do
      assert {:error, :area_invalid} = mem_read(@mem1, @objects_verified, 2, 7)
    end

    test "memory read exceeds max apdu length" do
      assert {:error, :max_apdu_exceeded} = mem_read(@mem2, @objects_verified, 13, 1)
    end
  end

  test "read_table" do
    assert {:ok, @table_size, @table_data} == Mem.read_table(@table_mem, 3, 2)
  end
end
