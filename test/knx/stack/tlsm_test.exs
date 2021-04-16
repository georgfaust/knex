defmodule KnxTest do
  use ExUnit.Case, async: false

  alias Knx.State, as: S
  alias Knx.Frame, as: F

  @own_addr 100
  @remote_addr 200
  @seq 0
  @auth_level 0
  @data <<0b1111_010010::10, @auth_level>>
  @max_rep 3

  @t_ack <<0b11::2, @seq::4, 0b10::2>>
  @t_nak <<0b11::2, @seq::4, 0b11::2>>
  @t_connect <<0b1000_0000::8>>
  @t_discon <<0b1000_0001::8>>
  @data_con <<0b01::2, @seq::4, @data::bits>>

  @tx_connect_frm Helper.get_frame(src: @own_addr, dest: @remote_addr, data: @t_connect)
  @rx_connect_frm Helper.get_frame(src: @remote_addr, dest: @own_addr, data: @t_connect)
  @tx_disconn_frm Helper.get_frame(src: @own_addr, dest: @remote_addr, data: @t_discon)
  @rx_disconn_frm Helper.get_frame(src: @remote_addr, dest: @own_addr, data: @t_discon)
  @tx_datacon_frm Helper.get_frame(src: @own_addr, dest: @remote_addr, data: @data_con)
  @rx_datacon_frm Helper.get_frame(src: @remote_addr, dest: @own_addr, data: @data_con)
  @tx_ack_frm Helper.get_frame(src: @own_addr, dest: @remote_addr, data: @t_ack)
  @rx_ack_frm Helper.get_frame(src: @remote_addr, dest: @own_addr, data: @t_ack)
  @tx_nak_frm Helper.get_frame(src: @own_addr, dest: @remote_addr, data: @t_nak)
  @rx_nak_frm Helper.get_frame(src: @remote_addr, dest: @own_addr, data: @t_nak)

  # 03.03.04 - Transport Layer - 5.5 State Diagrams
  describe "5.5.1 Connect and Disconnect" do
    test "5.5.1.1 - Connect from a remote Device" do
      assert {
               [
                 {:timer, :start, :connection},
                 {:user, :ind, {:t_connect, _}}
               ],
               %S{c_addr: @remote_addr, handler: :o_idle}
             } =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :closed},
                 [{:dl, :ind, @rx_connect_frm}]
               )
    end

    test "5.5.1.2 - Connect from a remote Device during an existing Connection" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: ^handler}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr + 1, addr: @own_addr, handler: handler},
                   [{:dl, :ind, @rx_connect_frm}]
                 )
      end)
    end

    test "5.5.1.3 Disconnect from a remote Device" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, :connection},
                   {:timer, :stop, :ack},
                   {:user, :ind, {:t_discon, _}}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler},
                   [{:dl, :ind, @rx_disconn_frm}]
                 )
      end)
    end

    test "5.5.1.4(5) Connect from the local User to a (non)existing Device" do
      assert {
               [
                 {:timer, :start, :connection},
                 {:driver, :transmit, @tx_connect_frm}
               ],
               %S{handler: :o_idle}
             } =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :closed},
                 [{:al, :req, %F{dest: @remote_addr, service: :t_connect}}]
               )

      # 5.5.1.4
      assert {[{:user, :conf, {:t_connect, _}}], %S{handler: :o_idle}} =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :o_idle},
                 [{:dl, :conf, @tx_connect_frm}]
               )

      # 5.5.1.5
      assert {
               [
                 {:timer, :stop, :connection},
                 {:timer, :stop, :ack},
                 {:user, :ind, {:t_discon, _}}
               ],
               %S{handler: :closed}
             } =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :o_idle},
                 [{:dl, :conf_error, @tx_connect_frm}]
               )
    end

    test "5.5.1.6 Connect from the local User during an existing Connection" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, :connection},
                   {:timer, :stop, :ack},
                   {:user, :ind, {:t_discon, _}},
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler},
                   [{:al, :req, %F{dest: @remote_addr, service: :t_connect}}]
                 )
      end)
    end

    test "5.5.1.8 Disconnect from the local User without an existing Connection" do
      assert {
               [
                 {:timer, :stop, :connection},
                 {:timer, :stop, :ack},
                 {:user, :conf, {:t_discon, _}}
               ],
               %S{handler: :closed}
             } =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :closed},
                 [{:al, :req, %F{dest: @remote_addr, service: :t_discon}}]
               )
    end

    test "5.5.1.9 Connection timeout" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, :connection},
                   {:timer, :stop, :ack},
                   {:user, :ind, {:t_discon, _}},
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler},
                   [{:tlsm, :timeout, :connection}]
                 )
      end)
    end
  end

  describe "5.5.2 Reception of Data" do
    test "5.5.2.1 Reception of a correct N_Data_Individual" do
      assert {
               [
                 {:timer, :restart, :connection},
                 {:todo, :ind, %F{apci: :auth_resp, data: [@auth_level]}},
                 {:driver, :transmit, @tx_ack_frm}
               ],
               %S{handler: :o_idle}
             } =
               Knx.handle_impulses(
                 %S{c_addr: @remote_addr, addr: @own_addr, handler: :o_idle, r_seq: @seq},
                 [{:dl, :ind, @rx_datacon_frm}]
               )
    end

    test "5.5.2.2 Reception of a repeated N_Data_Individual" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :restart, :connection},
                   {:driver, :transmit, @tx_ack_frm}
                 ],
                 %S{handler: ^handler}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler, r_seq: @seq + 1},
                   [{:dl, :ind, @rx_datacon_frm}]
                 )
      end)
    end

    test "5.5.2.3 Reception of data N_Data_Individual with wrong sequence Number" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :restart, :connection},
                   {:driver, :transmit, @tx_nak_frm}
                 ],
                 %S{handler: ^handler}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler, r_seq: @seq + 2},
                   [{:dl, :ind, @rx_datacon_frm}]
                 )
      end)
    end

    test "5.5.2.4 Reception of data N_Data_Individual with wrong Source Address" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: ^handler}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr + 1, addr: @own_addr, handler: handler},
                   [{:dl, :ind, @rx_datacon_frm}]
                 )
      end)
    end
  end

  describe "5.5.3 Transmission of Data" do
    test "5.5.3.1 T_DATA-Request from the local User" do
      assert {
               [
                 {:timer, :restart, :connection},
                 {:timer, :start, :ack},
                 {:driver, :transmit, @tx_datacon_frm}
               ],
               %S{handler: :o_wait}
             } =
               Knx.handle_impulses(
                 %S{c_addr: @remote_addr, addr: @own_addr, handler: :o_idle},
                 [
                   {:al, :req,
                    %F{
                      dest: @remote_addr,
                      service: :t_data_con,
                      apci: :auth_resp,
                      data: [@auth_level]
                    }}
                 ]
               )

      assert {
               [
                 {:timer, :restart, :connection},
                 {:timer, :stop, :ack},
                 {:user, :conf, %F{}}
               ],
               %S{handler: :o_idle}
             } =
               Knx.handle_impulses(
                 %S{
                   c_addr: @remote_addr,
                   addr: @own_addr,
                   handler: :o_wait,
                   stored_frame: %F{
                     dest: @remote_addr,
                     service: :t_data_con,
                     apci: :auth_resp,
                     data: [@auth_level]
                   }
                 },
                 [{:dl, :ind, @rx_ack_frm}]
               )
    end

    test "5.5.3.2 Reception of a T_ACK_PDU with wrong Sequence Number" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, :connection},
                   {:timer, :stop, :ack},
                   {:user, :ind, {:t_discon, _}},
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{
                     c_addr: @remote_addr,
                     addr: @own_addr,
                     s_seq: @seq + 2,
                     handler: handler
                   },
                   [{:dl, :ind, @rx_ack_frm}]
                 )
      end)
    end

    test "5.5.3.3 Reception of T_ACK_PDU with wrong Connecton Address" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: ^handler}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr + 1, addr: @own_addr, handler: handler},
                   [{:dl, :ind, @rx_ack_frm}]
                 )
      end)
    end

    test "5.5.3.4 Reception of T_NAK_PDU with wrong Sequence Number" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, :connection},
                   {:timer, :stop, :ack},
                   {:user, :ind, {:t_discon, _}},
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler, s_seq: 4},
                   [{:dl, :ind, @rx_nak_frm}]
                 )
      end)
    end

    test "5.5.3.5 Reception of T_NAK_PDU with correct Sequence Number" do
      assert {
               [
                 {:timer, :restart, :connection},
                 {:timer, :stop, :ack},
                 {:driver, :transmit, @tx_datacon_frm}
               ],
               %S{handler: :o_wait}
             } =
               Knx.handle_impulses(
                 %S{
                   c_addr: @remote_addr,
                   addr: @own_addr,
                   handler: :o_wait,
                   s_seq: @seq,
                   stored_frame: %F{
                     dest: @remote_addr,
                     service: :t_data_con,
                     apci: :auth_resp,
                     data: @data
                   }
                 },
                 [{:dl, :ind, @rx_nak_frm}]
               )
    end

    test "5.5.3.6 Reception of T_NAK_PDU and maximum Number of Repetitions is reached" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, :connection},
                   {:timer, :stop, :ack},
                   {:user, :ind, {:t_discon, nil}},
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{
                     c_addr: @remote_addr,
                     addr: @own_addr,
                     handler: handler,
                     s_seq: @seq,
                     rep: @max_rep,
                     stored_frame: %F{
                       dest: @remote_addr,
                       service: :t_data_con,
                       seq: @seq,
                       data: @data
                     }
                   },
                   [{:dl, :ind, @rx_nak_frm}]
                 )
      end)
    end

    test "5.5.3.7 Reception of T_NAK_PDU with wrong Connection Address" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {[
                  {:driver, :transmit, @tx_disconn_frm}
                ],
                %S{handler: ^handler}} =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr + 1, addr: @own_addr, handler: handler},
                   [{:dl, :ind, @rx_nak_frm}]
                 )
      end)
    end
  end
end
