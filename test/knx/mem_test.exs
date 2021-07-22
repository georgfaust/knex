defmodule MemTest do
  use ExUnit.Case

  alias Knx.Mem
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @mem1 <<0::64>>
  @mem2 <<0::128>>

  setup do
    Cache.start_link(%{})
    :timer.sleep(1)
    :ok
  end

  def mem_read(mem, number, addr) do
    Cache.put(:mem, mem)

    case Mem.handle(
           {:mem, :ind, %F{apci: :mem_read, data: [number, addr]}},
           %S{}
         ) do
      [] ->
        {:error, :max_apdu_exceeded}

      [{:al, :req, %F{apci: :mem_resp, data: [0, ^addr, <<>>]}}] ->
        {:error, :area_invalid}

      [{:al, :req, %F{apci: :mem_resp, data: [^number, ^addr, data]}}] ->
        data
    end
  end

  def mem_write(mem, verify, addr, data) do
    Cache.put(:mem, mem)
    number = byte_size(data)

    case Mem.handle(
           {:mem, :ind, %F{apci: :mem_write, data: [number, addr, data]}},
           %S{verify: verify}
         ) do
      [] when verify ->
        {:error, :max_apdu_exceeded}

      [] when not verify ->
        Cache.get(:mem)

      [{:al, :req, %F{apci: :mem_resp, data: [0, ^addr, <<>>]}}] ->
        {:error, :area_invalid}

      [{:al, :req, %F{apci: :mem_resp, data: [^number, ^addr, ^data]}}] ->
        assert verify
        Cache.get(:mem)
    end
  end

  describe "mem_read.ind and mem_write.ind" do
    test "successful write and read" do
      assert <<_::16, 0xDEAD::16, _::bytes>> = mem1 = mem_write(@mem1, true, 2, <<0xDEAD::16>>)

      assert <<0x00DE_AD00::32>> = mem_read(mem1, 4, 1)

      assert <<_::16, 0xDEAD_BEEF::32, _::bytes>> =
               mem1 = mem_write(mem1, true, 4, <<0xBEEF::16>>)

      assert <<0x0000_DEAD_BEEF_0000::64>> = mem_read(mem1, 8, 0)
    end

    test "memory write with inactive verify mode" do
      assert <<_::16, 0xDEAD::16, _::bytes>> = mem_write(@mem1, false, 2, <<0xDEAD::16>>)
    end

    test "invalid memory write" do
      assert {:error, :area_invalid} = mem_write(@mem1, true, 8, <<0xFF::8>>)
    end

    test "partially invalid memory write" do
      assert {:error, :area_invalid} = mem_write(@mem1, true, 7, <<0xFFFF::16>>)
    end

    test "memory write exceeds max apdu length" do
      assert {:error, :max_apdu_exceeded} = mem_write(@mem2, true, 1, <<1::112>>)
    end

    test "invalid memory read" do
      assert {:error, :area_invalid} = mem_read(@mem1, 1, 8)
    end

    test "partially invalid memory read" do
      assert {:error, :area_invalid} = mem_read(@mem1, 2, 7)
    end

    test "memory read exceeds max apdu length" do
      assert {:error, :max_apdu_exceeded} = mem_read(@mem2, 13, 1)
    end
  end


end
