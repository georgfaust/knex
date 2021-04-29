defmodule Knx.Ail.CoreTest do
  use ExUnit.Case

  alias Knx.Ail.GoServer, as: GOS
  alias Knx.Ail.GroupObject, as: GO
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @own_addr 100
  @remote_addr 200

  @addr_t_ind 0
  @addr_t_group 1

  # [START]: TPCIs >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @t_data_group <<0b0000_00::6>>
  @t_data_ind <<0b0000_00::6>>

  # [END]: TPCIs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  # [START]: APCIs >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @group_read <<0b0000_000000::10>>
  @group_resp <<0b0001::4>>
  @group_write <<0b0010::4>>

  # NOTE: in the APCI table mem_X have 6 bit,
  #   in the pdu desc they have 4 bits.
  #   using 4 bits.
  @mem_read <<0b1000::4>>
  @mem_resp <<0b1001::4>>
  @mem_write <<0b1010::4>>

  @device_dest_read <<0b1100::4>>
  @device_dest_resp <<0b1101::4>>

  @auth_request <<0b1111_010001::10>>
  @auth_resp <<0b1111_010010::10>>
  @key_write <<0b1111_010011::10>>
  @key_resp <<0b1111_010100::10>>

  @prop_read <<0b1111_010101::10>>
  @prop_resp <<0b1111_010110::10>>
  @prop_write <<0b1111_010111::10>>
  @prop_dest_read <<0b1111_011000::10>>
  @prop_dest_resp <<0b1111_011001::10>>

  # [END]: APCIs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  # [START]: GO-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  # Group tests fail because required context in go_server.ex is not yet handled

  # assoc_tab and go_tab not yet used here
  @assoc_tab [
    {1, 1},
    {2, 2},
    {3, 3},
    {4, 4},
    {5, 5},
    {6, 6}
  ]

  @go_tab %{
    1 => %GO{asap: 1, transmits: true},
    2 => %GO{asap: 2, writable: true},
    3 => %GO{asap: 3, readable: true},
    4 => %GO{asap: 4, updatable: true},
    5 => %GO{asap: 5, transmits: true, readable: true},
    6 => %GO{asap: 6, transmits: true, readable: true, updatable: true}
  }

  @group_read_frm_dest_1 Helper.get_frame(
                           src: @own_addr,
                           dest: 1,
                           addr_t: @addr_t_group,
                           data: <<@t_data_group::bits, @group_read::bits>>
                         )

  @group_read_frm_dest_3 Helper.get_frame(
                           src: @own_addr,
                           dest: 3,
                           addr_t: @addr_t_group,
                           data: <<@t_data_group::bits, @group_read::bits>>
                         )

  @group_write_frm_dest_5_data_1 Helper.get_frame(
                                   src: @own_addr,
                                   dest: 5,
                                   addr_t: @addr_t_group,
                                   data: <<@t_data_group::bits, @group_write::bits, 1::6>>
                                 )

  @group_write_frm_dest_2_data_2 Helper.get_frame(
                                   src: @remote_addr,
                                   dest: 2,
                                   addr_t: @addr_t_group,
                                   data: <<@t_data_group::bits, @group_write::bits, 2::6>>
                                 )

  @group_write_frm_dest_99_data_2 Helper.get_frame(
                                    src: @remote_addr,
                                    dest: 99,
                                    addr_t: @addr_t_group,
                                    data: <<@t_data_group::bits, @group_write::bits, 2::6>>
                                  )

  @group_resp_frm_dest_3_data_0 Helper.get_frame(
                                  src: @own_addr,
                                  dest: 3,
                                  addr_t: @addr_t_group,
                                  data: <<@t_data_group::bits, @group_resp::bits, 0::6>>
                                )

  @group_resp_frm_dest_4_data_2 Helper.get_frame(
                                  src: @remote_addr,
                                  dest: 4,
                                  addr_t: @addr_t_group,
                                  data: <<@t_data_group::bits, @group_resp::bits, 2::6>>
                                )

  @group_resp_frm_dest_99_data_2 Helper.get_frame(
                                   src: @remote_addr,
                                   dest: 99,
                                   addr_t: @addr_t_group,
                                   data: <<@t_data_group::bits, @group_resp::bits, 2::6>>
                                 )

  test "group_read.req" do
    assert {[
              {:driver, :transmit, @group_read_frm_dest_1}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:go, :req, %F{apci: :group_read, asap: 1, tsap: nil}}]
             )

    assert {[], %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:go, :req, %F{apci: :group_read, asap: 3, tsap: nil}}]
             )
  end

  test "group_write.req" do
    assert {[
              {:user, :go_value, {5, <<1>>}},
              {:driver, :transmit, @group_write_frm_dest_5_data_1}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:go, :req, %F{apci: :group_write, asap: 5, tsap: nil, data: <<1>>}}]
             )

    # this will be deferred
    assert {[
              {:user, :go_value, {5, <<1>>}}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:go, :req, %F{apci: :group_write, asap: 5, tsap: nil, data: <<1>>}}]
             )

    # conf recalls deferred impulse
    assert {[
              {:driver, :transmit, @group_write_frm_dest_5_data_1}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:go, :conf, %F{}}]
             )

    assert {[], %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:go, :req, %F{apci: :group_write, asap: 2, tsap: nil, data: <<1>>}}]
             )
  end

  test "group_read.ind" do
    assert {[
              {:user, :go_value, {3, 0}},
              {:driver, :transmit, @group_resp_frm_dest_3_data_0}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:dl, :ind, @group_read_frm_dest_3}]
             )
  end

  test "group_write.ind" do
    # TODO testen mit mehr assocs auf einem tsap
    assert {[
              {:user, :go_value, {2, <<2>>}}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:dl, :ind, @group_write_frm_dest_2_data_2}]
             )

    assert {[], %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:dl, :ind, @group_write_frm_dest_99_data_2}]
             )
  end

  test "group_resp.ind" do
    # TODO testen mit mehr assocs auf einem tsap
    assert {[
              {:user, :go_value, {4, <<2>>}}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:dl, :ind, @group_resp_frm_dest_4_data_2}]
             )

    assert {[], %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:dl, :ind, @group_resp_frm_dest_99_data_2}]
             )
  end

  # [END]: GO-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
end
