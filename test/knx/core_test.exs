defmodule Knx.Ail.CoreTest do
  use ExUnit.Case

  alias Knx.Frame, as: F
  alias Knx.State, as: S
  alias Knx.Auth

  @addr_tab Helper.get_addr_tab()
  @assoc_tab Helper.get_assoc_tab()
  @go_tab Helper.get_go_tab()
  @go_values Helper.get_go_values()

  @cache %{
    {:objects, 0} => Helper.get_device_props(0),
    addr_tab: @addr_tab,
    go_tab: @go_tab,
    assoc_tab: @assoc_tab,
    go_values: @go_values
  }

  @own_addr 100
  @remote_addr 200

  @addr_t_ind 0
  @addr_t_group 1

  # [START]: TPCIs >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @t_data_group <<0b0000_00::6>>
  @t_data_individual <<0b0000_00::6>>
  @t_data_con_seq_0 <<0b0100_00::6>>

  # [END]: TPCIs <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  # [START]: APCIs >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @group_read <<0b0000_000000::10>>
  @group_resp <<0b0001::4>>
  @group_write <<0b0010::4>>

  # NOTE: in the APCI table mem_X have 6 bit,
  #   in the pdu desc they have 4 bits.
  #   using 4 bits.
  # @mem_read <<0b1000::4>>
  @mem_resp <<0b1001::4>>
  @mem_write <<0b1010::4>>

  # @device_dest_read <<0b1100::4>>
  # @device_dest_resp <<0b1101::4>>

  # @auth_request <<0b1111_010001::10>>
  # @auth_resp <<0b1111_010010::10>>
  @key_write <<0b1111_010011::10>>
  @key_resp <<0b1111_010100::10>>
  # @prop_read <<0b1111_010101::10>>
  # @prop_resp <<0b1111_010110::10>>
  # @prop_write <<0b1111_010111::10>>
  @prop_desc_read <<0b1111_011000::10>>
  @prop_desc_resp <<0b1111_011001::10>>

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
            ], %S{}} = Knx.handle_impulses(state, [{:dl, :conf, @group_write_frm_dest_5_data_1}])

    assert {[], %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [
                 {:go, :req,
                  %F{apci: :group_write, asap: 2, tsap: nil, data: <<1>>, service: :t_data_group}}
               ]
             )
  end

  test "group_read.ind" do
    assert {[
              {:user, :go_value, {3, <<0::6>>}},
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

  # [START]: IO-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @pid_manufacturer_id 12
  @p_idx_manufacturer_id 4
  @pdt_manufacturer_id 4

  @prop_desc_read_frm Helper.get_frame(
                        src: @remote_addr,
                        dest: @own_addr,
                        addr_t: @addr_t_ind,
                        data:
                          <<@t_data_individual::bits, @prop_desc_read::bits, 0,
                            @pid_manufacturer_id, 0>>
                      )

  @prop_desc_resp_frm Helper.get_frame(
                        src: @own_addr,
                        dest: @remote_addr,
                        addr_t: @addr_t_ind,
                        # a_prop_desc_resp_pdu:
                        #  <<o_idx, pid, p_idx, write::1, 0::1, pdt::6, 0::4, max::12,
                        #  r_lvl::4, w_lvl::4>>
                        data:
                          <<@t_data_individual::bits, @prop_desc_resp::bits, 0,
                            @pid_manufacturer_id, @p_idx_manufacturer_id, 0::1, 0::1,
                            @pdt_manufacturer_id::6, 0::4, 1::12, 3::4, 0::4>>
                      )

  test "responds to prop_desc_read: existing pid" do
    assert {[
              {:driver, :transmit, @prop_desc_resp_frm}
            ],
            %S{}} =
             Knx.handle_impulses(
               %S{addr: @own_addr},
               [{:dl, :ind, @prop_desc_read_frm}]
             )
  end

  # [END]: IO-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  # [START]: Auth-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @key_write_frm Helper.get_frame(
                   src: @remote_addr,
                   dest: @own_addr,
                   addr_t: @addr_t_ind,
                   data: <<@t_data_con_seq_0::bits, @key_write::bits, 3, 0xAA::32>>
                 )

  @key_response_frm Helper.get_frame(
                      src: @own_addr,
                      dest: @remote_addr,
                      addr_t: @addr_t_ind,
                      data: <<@t_data_con_seq_0::bits, @key_resp::bits, 3>>
                    )

  test "key_write.ind" do
    assert {
             [
               {:timer, :restart, {:tlsm, :connection}},
               # ACK TODO @ack_frame
               {:driver, :transmit, <<176, 0, 100, 0, 200, 96, 194>>},
               {:timer, :restart, {:tlsm, :connection}},
               {:timer, :start, {:tlsm, :ack}},
               {:driver, :transmit, @key_response_frm}
             ],
             %S{auth: %Auth{} = new_auth}
           } =
             Knx.handle_impulses(
               %S{auth: %Auth{}, addr: @own_addr, c_addr: @remote_addr, handler: :o_idle},
               [{:dl, :ind, @key_write_frm}]
             )

    assert %Auth{keys: [0, 0, 0, 0xAA]} = new_auth
  end

  # [END]: Auth-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  # [START]: Mem-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

  @mem_write_frm Helper.get_frame(
                   src: @remote_addr,
                   dest: @own_addr,
                   addr_t: @addr_t_ind,
                   data: <<@t_data_con_seq_0::bits, @mem_write::bits, 2::6, 2::16, 0xDEAD::16>>
                 )

  @mem_response_frm Helper.get_frame(
                      src: @own_addr,
                      dest: @remote_addr,
                      addr_t: @addr_t_ind,
                      data: <<@t_data_individual::bits, @mem_resp::bits, 2::6, 2::16, 0xDEAD::16>>
                    )

  # @tag :current
  # test "mem_write.ind" do
  #   assert {
  #            [{:driver, :transmit, @mem_response_frm}],
  #            %S{mem: new_mem}
  #          } =
  #            Knx.handle_impulses(
  #              %S{
  #                addr: @own_addr,
  #                mem: <<0::64>>,
  #                objects: %{0 => Helper.get_device_props(1, true)}
  #              },
  #              [{:dl, :ind, @mem_write_frm}]
  #            )
  # end

  # [END]: Mem-specific tests >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
end
