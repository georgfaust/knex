defmodule Knx.TlTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Frame, as: F

  require Knx.Defs
  import Knx.Defs

  alias Knx.Stack.{Dl, Nl, Tl, Tlsm, Al}

  @std 0b10
  @r_addr 0xDE
  @o_addr 0xAD
  @group_addr 0x0001
  @hops 6
  @len 1
  @prio 0
  @t_data_group <<0b0000_00::6>>
  @a_group_read <<0b0000_0000_00::10>>
  @addr_tab [-1, 99, @group_addr]
  @tsap 2
  @seq 3
  @t_ack <<0b11::2, @seq::4, 0b10::2>>

  setup do
    Cache.start_link(%{addr_tab: @addr_tab})
    :ok
  end

  describe "stack up" do
    test "dl decodes frame" do
      assert [
               {:nl, :ind,
                %F{
                  src: @r_addr,
                  dest: @group_addr,
                  addr_t: addr_t(:grp),
                  hops: @hops,
                  len: @len,
                  prio: @prio,
                  data: <<@t_data_group::bits, @a_group_read::bits>>,
                  ok?: nil
                }}
             ] =
               Dl.handle(
                 {:dl, :ind,
                  <<
                    @std::2,
                    3::2,
                    @prio::2,
                    0::2,
                    @r_addr::16,
                    @group_addr::16,
                    addr_t(:grp)::1,
                    @hops::3,
                    @len::4,
                    @t_data_group::bits,
                    @a_group_read::bits
                  >>},
                 %S{}
               )
    end

    test "nl lets individual addressed frame with device's ind addr pass" do
      assert [{:tl, :ind, %F{}}] =
               Nl.handle(
                 {:nl, :ind, %F{dest: @o_addr, addr_t: addr_t(:ind)}},
                 %S{addr: @o_addr}
               )
    end

    test "nl drops not-addressed individual addressed frame" do
      assert [] =
               Nl.handle(
                 {:nl, :ind, %F{dest: @o_addr + 1, addr_t: addr_t(:ind)}},
                 %S{addr: @o_addr}
               )
    end

    test "nl lets grp-addressed pass" do
      assert [{:tl, :ind, %F{}}] =
               Nl.handle(
                 {:nl, :ind, %F{dest: @group_addr, addr_t: addr_t(:grp)}},
                 %S{addr: @o_addr}
               )
    end

    test "t_data_group: tl sets tsap and service" do
      assert [{:tlsm, :ind, %F{tsap: @tsap, service: :t_data_group, data: @a_group_read}}] =
               Tl.handle(
                 {:tl, :ind,
                  %F{
                    dest: @group_addr,
                    addr_t: addr_t(:grp),
                    data: <<@t_data_group::bits, @a_group_read::bits>>
                  }},
                 %S{}
               )
    end

    test "t_ack: tl sets seq and service, keeps dest" do
      assert [{:tlsm, :ind, %F{seq: @seq, service: :t_ack, dest: @o_addr, data: <<>>}}] =
               Tl.handle(
                 {:tl, :ind, %F{dest: @o_addr, addr_t: addr_t(:ind), data: @t_ack}},
                 %S{}
               )
    end

    # NOTE: more tlsm tests in stack/tlsm_test.exs
    test "tlsm does nothing" do
      assert {%S{}, [{:al, :ind, %F{}}]} =
               Tlsm.handle(
                 {:tlsm, :ind, %F{service: :t_data_group}},
                 %S{}
               )
    end

    test "al decodes apdu" do
      assert [{:go, :ind, %F{apci: :group_read}}] =
               Al.handle(
                 {:al, :ind, %F{service: :t_data_group, data: @a_group_read}},
                 %S{}
               )
    end
  end

  describe "stack down" do
    test "al encodes a_service" do
      assert [{:tlsm, :req, %F{data: @a_group_read}}] =
               Al.handle(
                 {
                   :al,
                   :req,
                   %F{tsap: 1, apci: :group_read, service: :t_data_group}
                 },
                 %S{}
               )
    end

    test "tlsm does nothing" do
      assert {%S{}, [{:tl, :req, %F{}}]} =
               Tlsm.handle(
                 {:tlsm, :req, %F{service: :t_data_group}},
                 %S{}
               )
    end

    test "tl encodes tpci and gets addr from tsap" do
      assert [
               {:nl, :req,
                %F{
                  dest: @group_addr,
                  addr_t: addr_t(:grp),
                  data: <<@t_data_group::bits, @a_group_read::bits>>
                }}
             ] =
               Tl.handle(
                 {:tl, :req, %F{tsap: @tsap, service: :t_data_group, data: @a_group_read}},
                 %S{}
               )
    end

    test "nl set hops unlimited" do
      assert [{:dl, :req, %F{hops: 7}}] = Nl.handle({:nl, :req, %F{hops: :hops_unlimited}}, %S{})
    end

    test "nl set hops network param" do
      assert [
               {:dl, :req, %F{hops: 6}}
             ] = Nl.handle({:nl, :req, %F{hops: :hops_nw_param}}, %S{hops: 6})
    end

    test "dl encodes frame" do
      assert [
               {:driver, :transmit,
                {_, _,
                 <<
                   @std::2,
                   3::2,
                   @prio::2,
                   0::2,
                   @r_addr::16,
                   @group_addr::16,
                   addr_t(:grp)::1,
                   @hops::3,
                   @len::4,
                   @t_data_group::bits,
                   @a_group_read::bits
                 >>}}
             ] =
               Dl.handle(
                 {
                   :dl,
                   :req,
                   %F{
                     src: @r_addr,
                     dest: @group_addr,
                     addr_t: addr_t(:grp),
                     hops: @hops,
                     len: @len,
                     prio: @prio,
                     data: <<@t_data_group::bits, @a_group_read::bits>>,
                     ok?: nil
                   }
                 },
                 %S{}
               )
    end
  end
end
