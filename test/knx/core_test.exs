defmodule Knx.Ail.CoreTest do
  use ExUnit.Case

  # alias Knx.Ail.GoServer, as: GOS
  # alias Knx.Ail.GroupObject, as: GO
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @addr_tab Helper.get_addr_tab()
  @assoc_tab Helper.get_assoc_tab()
  @go_tab Helper.get_go_tab()

  @cache %{
    addr_tab: @addr_tab,
    go_tab: @go_tab,
    assoc_tab: @assoc_tab,
    go_values: %{}
  }

  @own_addr 100
  @remote_addr 200

  # @addr_t_ind 0
  @addr_t_group 1

  # [START]: TPCIs >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @t_data_group <<0b0000_00::6>>
  # @t_data_ind <<0b0000_00::6>>

  # [END]: TPCIs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  # [START]: APCIs >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @group_read <<0b0000_000000::10>>
  @group_resp <<0b0001::4>>
  @group_write <<0b0010::4>>

  # NOTE: in the APCI table mem_X have 6 bit,
  #   in the pdu desc they have 4 bits.
  #   using 4 bits.
  # @mem_read <<0b1000::4>>
  # @mem_resp <<0b1001::4>>
  # @mem_write <<0b1010::4>>

  # @device_dest_read <<0b1100::4>>
  # @device_dest_resp <<0b1101::4>>

  # @auth_request <<0b1111_010001::10>>
  # @auth_resp <<0b1111_010010::10>>
  # @key_write <<0b1111_010011::10>>
  # @key_resp <<0b1111_010100::10>>
  # @prop_read <<0b1111_010101::10>>
  # @prop_resp <<0b1111_010110::10>>
  # @prop_write <<0b1111_010111::10>>
  # @prop_dest_read <<0b1111_011000::10>>
  # @prop_dest_resp <<0b1111_011001::10>>

  # [END]: APCIs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  # [START]: GO-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  # Group tests fail because required context in go_server.ex is not yet handled

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

  setup do
    Cache.start_link(@cache)
    :ok
  end

  test "group_read.req" do
    assert {[
              {:driver, :transmit, @group_read_frm_dest_1}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:go, :req, %F{apci: :group_read, asap: 1, tsap: nil, service: :t_data_group}}]
             )

    assert {[], %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:go, :req, %F{apci: :group_read, asap: 3, tsap: nil, service: :t_data_group}}]
             )
  end

  test "group_write.req" do
    assert {[
              {:user, :go_value, {5, [<<1::6>>]}},
              {:driver, :transmit, @group_write_frm_dest_5_data_1}
            ],
            %S{} = state} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [
                 {:go, :req,
                  %F{
                    apci: :group_write,
                    asap: 5,
                    tsap: nil,
                    data: [<<1::6>>],
                    service: :t_data_group
                  }}
               ]
             )

    # this will be deferred
    assert {[
              {:user, :go_value, {5, [<<1::6>>]}}
            ],
            %S{} = state} =
             Knx.handle_impulses(
               state,
               [
                 {:go, :req,
                  %F{
                    apci: :group_write,
                    asap: 5,
                    tsap: nil,
                    data: [<<1::6>>],
                    service: :t_data_group
                  }}
               ]
             )

    # conf recalls deferred impulse
    assert {[
              {:driver, :transmit, @group_write_frm_dest_5_data_1}
            ],
            %S{} = state} =
             Knx.handle_impulses(state, [{:dl, :conf, @group_write_frm_dest_5_data_1}])

    assert {[], %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [
                 {:go, :req,
                  %F{apci: :group_write, asap: 2, tsap: nil, data: <<1>>, service: :t_data_group}}
               ]
             )
  end

  # TODO go_values muessen als binary gespeichert werden.
  #   user muss dann per API/datapoints decoden.
  # test "group_read.ind" do
  #   assert {[
  #             {:user, :go_value, {3, 0}},
  #             {:driver, :transmit, @group_resp_frm_dest_3_data_0}
  #           ],
  #           %S{}} =
  #            Knx.handle_impulses(
  #              %S{addr: @own_addr},
  #              [{:dl, :ind, @group_read_frm_dest_3}]
  #            )
  # end

  test "group_write.ind" do
    # TODO testen mit mehr assocs auf einem tsap
    assert {[
              {:user, :go_value, {2, [<<2::6>>]}}
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

  @tag :current
  test "group_resp.ind" do
    # TODO testen mit mehr assocs auf einem tsap
    assert {[
              {:user, :go_value, {4, [<<2::6>>]}}
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
