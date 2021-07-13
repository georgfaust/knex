defmodule KnxTest do
  use ExUnit.Case, async: false

  alias Knx.State, as: S
  alias Knx.Frame, as: F

  alias Knx.DataCemiFrame, as: DCF

  require Knx.Defs
  import Knx.Defs

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
  @auth_resp 0b1111_010010
  @data_con <<0b01::2, @seq::4, @data::bits>>

  @connect_req DCF.encode(:req, %F{
                 src: @own_addr,
                 dest: @remote_addr,
                 addr_t: addr_t(:ind),
                 data: @t_connect
               })

  @connect_conf_ok DCF.encode(:conf, %F{
                     src: @own_addr,
                     dest: @remote_addr,
                     addr_t: addr_t(:ind),
                     data: @t_connect,
                     confirm: 0
                   })

  @connect_conf_error DCF.encode(:conf, %F{
                        src: @own_addr,
                        dest: @remote_addr,
                        addr_t: addr_t(:ind),
                        data: @t_connect,
                        confirm: 1
                      })

  @rx_connect_frm DCF.encode(:ind, %F{
                    src: @remote_addr,
                    dest: @own_addr,
                    addr_t: addr_t(:ind),
                    data: @t_connect
                  })

  @tx_disconn_frm DCF.encode(:req, %F{
                    src: @own_addr,
                    dest: @remote_addr,
                    addr_t: addr_t(:ind),
                    data: @t_discon
                  })
  @rx_disconn_frm DCF.encode(:ind, %F{
                    src: @remote_addr,
                    dest: @own_addr,
                    addr_t: addr_t(:ind),
                    data: @t_discon
                  })

  @tx_datacon_frm DCF.encode(:req, %F{
                    src: @own_addr,
                    dest: @remote_addr,
                    addr_t: addr_t(:ind),
                    data: @data_con
                  })

  @rx_datacon_frm DCF.encode(:ind, %F{
                    src: @remote_addr,
                    dest: @own_addr,
                    addr_t: addr_t(:ind),
                    data: @data_con
                  })

  @tx_ack_frm DCF.encode(:req, %F{
                src: @own_addr,
                dest: @remote_addr,
                addr_t: addr_t(:ind),
                data: @t_ack
              })

  @rx_ack_frm DCF.encode(:ind, %F{
                src: @remote_addr,
                dest: @own_addr,
                addr_t: addr_t(:ind),
                data: @t_ack
              })

  @tx_nak_frm DCF.encode(:req, %F{
                src: @own_addr,
                dest: @remote_addr,
                addr_t: addr_t(:ind),
                data: @t_nak
              })
  @rx_nak_frm DCF.encode(:ind, %F{
                src: @remote_addr,
                dest: @own_addr,
                addr_t: addr_t(:ind),
                data: @t_nak
              })

  # 03.03.04 - Transport Layer - 5.5 State Diagrams
  describe "5.5.1 Connect and Disconnect" do
    test "5.5.1.1 - Connect from a remote Device" do
      assert {
               [
                 {:timer, :start, {:tlsm, :connection}},
                 {:mgmt, :ind, %F{apci: :a_connect}}
               ],
               %S{c_addr: @remote_addr, handler: :o_idle}
             } =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :closed},
                 [{:dl, :up, @rx_connect_frm}]
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
                   [{:dl, :up, @rx_connect_frm}]
                 )
      end)
    end

    test "5.5.1.3 Disconnect from a remote Device" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, {:tlsm, :connection}},
                   {:timer, :stop, {:tlsm, :ack}},
                   {:mgmt, :ind, %F{apci: :a_discon}}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler},
                   [{:dl, :up, @rx_disconn_frm}]
                 )
      end)
    end

    test "5.5.1.4(5) Connect from the local User to a (non)existing Device" do
      assert {
               [
                 {:timer, :start, {:tlsm, :connection}},
                 {:driver, :transmit, @connect_req}
               ],
               %S{handler: :o_idle}
             } =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :closed},
                 [{:al, :req, %F{dest: @remote_addr, apci: :a_connect}}]
               )

      # 5.5.1.4
      assert {[
                {:mgmt, :conf, %F{apci: :a_connect}}
              ],
              %S{handler: :o_idle}} =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :o_idle},
                 [{:dl, :up, @connect_conf_ok}]
               )

      # 5.5.1.5
      assert {
               [
                 {:timer, :stop, {:tlsm, :connection}},
                 {:timer, :stop, {:tlsm, :ack}},
                 {:mgmt, :ind, %F{apci: :a_discon}}
               ],
               %S{handler: :closed}
             } =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :o_idle},
                 [{:dl, :up, @connect_conf_error}]
               )
    end

    test "5.5.1.6 Connect from the local User during an existing Connection" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, {:tlsm, :connection}},
                   {:timer, :stop, {:tlsm, :ack}},
                   {:mgmt, :ind, %F{apci: :a_discon}},
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler},
                   [{:al, :req, %F{dest: @remote_addr, apci: :a_connect}}]
                 )
      end)
    end

    test "5.5.1.8 Disconnect from the local User without an existing Connection" do
      assert {
               [
                 {:timer, :stop, {:tlsm, :connection}},
                 {:timer, :stop, {:tlsm, :ack}},
                 {:mgmt, :conf, %F{apci: :a_discon}}
               ],
               %S{handler: :closed}
             } =
               Knx.handle_impulses(
                 %S{addr: @own_addr, handler: :closed},
                 [{:al, :req, %F{dest: @remote_addr, apci: :a_discon}}]
               )
    end

    test "5.5.1.9 Connection timeout" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, {:tlsm, :connection}},
                   {:timer, :stop, {:tlsm, :ack}},
                   {:mgmt, :ind, %F{apci: :a_discon}},
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
                 {:timer, :restart, {:tlsm, :connection}},
                 {:mgmt, :ind, %F{apci: :auth_resp, data: [@auth_level]}},
                 {:driver, :transmit, @tx_ack_frm}
               ],
               %S{handler: :o_idle}
             } =
               Knx.handle_impulses(
                 %S{c_addr: @remote_addr, addr: @own_addr, handler: :o_idle, r_seq: @seq},
                 [{:dl, :up, @rx_datacon_frm}]
               )
    end

    test "5.5.2.2 Reception of a repeated N_Data_Individual" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :restart, {:tlsm, :connection}},
                   {:driver, :transmit, @tx_ack_frm}
                 ],
                 %S{handler: ^handler}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler, r_seq: @seq + 1},
                   [{:dl, :up, @rx_datacon_frm}]
                 )
      end)
    end

    test "5.5.2.3 Reception of data N_Data_Individual with wrong sequence Number" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :restart, {:tlsm, :connection}},
                   {:driver, :transmit, @tx_nak_frm}
                 ],
                 %S{handler: ^handler}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler, r_seq: @seq + 2},
                   [{:dl, :up, @rx_datacon_frm}]
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
                   [{:dl, :up, @rx_datacon_frm}]
                 )
      end)
    end
  end

  describe "5.5.3 Transmission of Data" do
    test "5.5.3.1 T_DATA-Request from the local User" do
      assert {
               [
                 {:timer, :restart, {:tlsm, :connection}},
                 {:timer, :start, {:tlsm, :ack}},
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
                 {:timer, :restart, {:tlsm, :connection}},
                 {:timer, :stop, {:tlsm, :ack}},
                 {:mgmt, :conf, %F{}}
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
                     data: <<@auth_resp::10, @auth_level>>
                   }
                 },
                 [{:dl, :up, @rx_ack_frm}]
               )
    end

    test "5.5.3.2 Reception of a T_ACK_PDU with wrong Sequence Number" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, {:tlsm, :connection}},
                   {:timer, :stop, {:tlsm, :ack}},
                   {:mgmt, :ind, %F{apci: :a_discon}},
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
                   [{:dl, :up, @rx_ack_frm}]
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
                   [{:dl, :up, @rx_ack_frm}]
                 )
      end)
    end

    test "5.5.3.4 Reception of T_NAK_PDU with wrong Sequence Number" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, {:tlsm, :connection}},
                   {:timer, :stop, {:tlsm, :ack}},
                   {:mgmt, :ind, %F{apci: :a_discon}},
                   {:driver, :transmit, @tx_disconn_frm}
                 ],
                 %S{handler: :closed}
               } =
                 Knx.handle_impulses(
                   %S{c_addr: @remote_addr, addr: @own_addr, handler: handler, s_seq: 4},
                   [{:dl, :up, @rx_nak_frm}]
                 )
      end)
    end

    test "5.5.3.5 Reception of T_NAK_PDU with correct Sequence Number" do
      assert {
               [
                 {:timer, :restart, {:tlsm, :connection}},
                 {:timer, :stop, {:tlsm, :ack}},
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
                 [{:dl, :up, @rx_nak_frm}]
               )
    end

    test "5.5.3.6 Reception of T_NAK_PDU and maximum Number of Repetitions is reached" do
      Enum.each([:o_idle, :o_wait], fn handler ->
        assert {
                 [
                   {:timer, :stop, {:tlsm, :connection}},
                   {:timer, :stop, {:tlsm, :ack}},
                   {:mgmt, :ind, %F{apci: :a_discon}},
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
                   [{:dl, :up, @rx_nak_frm}]
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
                   [{:dl, :up, @rx_nak_frm}]
                 )
      end)
    end
  end
end
