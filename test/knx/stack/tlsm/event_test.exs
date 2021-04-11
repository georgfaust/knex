defmodule Knx.Stack.Tlsm.TestEvent do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Frame, as: F
  import Knx.Stack.Tlsm.Event

  test "event" do
    assert :e00 == get_event(:ind, :t_connect, %F{src: 0}, %S{c_addr: 0})
    assert :e01 == get_event(:ind, :t_connect, %F{src: 0}, %S{c_addr: 0 + 1})
    assert :e02 == get_event(:ind, :t_discon, %F{src: 0}, %S{c_addr: 0})
    assert :e03 == get_event(:ind, :t_discon, %F{src: 0}, %S{c_addr: 0 + 1})
    assert :e04 == get_event(:ind, :t_data_con, %F{src: 0, seq: 7}, %S{c_addr: 0, r_seq: 7})
    assert :e05 == get_event(:ind, :t_data_con, %F{src: 0, seq: 7}, %S{c_addr: 0, r_seq: 8})
    assert :e05 == get_event(:ind, :t_data_con, %F{src: 0, seq: 0xF}, %S{c_addr: 0, r_seq: 0x0})
    assert :e05 == get_event(:ind, :t_data_con, %F{src: 0, seq: 0xF}, %S{c_addr: 0, r_seq: 0x10})
    assert :e06 == get_event(:ind, :t_data_con, %F{src: 0, seq: 7}, %S{c_addr: 0, r_seq: 9})
    assert :e07 == get_event(:ind, :t_data_con, %F{src: 0}, %S{c_addr: 0 + 1})
    assert :e08 == get_event(:ind, :t_ack, %F{src: 0, seq: 7}, %S{c_addr: 0, s_seq: 7})
    assert :e09 == get_event(:ind, :t_ack, %F{src: 0, seq: 7}, %S{c_addr: 0, s_seq: 8})
    assert :e10 == get_event(:ind, :t_ack, %F{src: 0}, %S{c_addr: 0 + 1})
    assert :e11 == get_event(:ind, :t_nak, %F{src: 0, seq: 7}, %S{c_addr: 0, s_seq: 8})
    # TODO rep -> state ?
    # assert :e12 == get_event(:ind, :t_nak, %F{src: 0, seq: 7, rep: 2}, %S{c_addr: 0, s_seq: 7})
    # assert :e13 == get_event(:ind, :t_nak, %F{src: 0, seq: 7, rep: 3}, %S{c_addr: 0, s_seq: 7})
    # assert :e13 == get_event(:ind, :t_nak, %F{src: 0, seq: 7, rep: 4}, %S{c_addr: 0, s_seq: 7})
    assert :e14 == get_event(:ind, :t_nak, %F{src: 0}, %S{c_addr: 0 + 1})
    assert :e15 == get_event(:req, :t_data_con, %F{}, %S{})
    assert :e25 == get_event(:req, :t_connect, %F{}, %S{})
    assert :e26 == get_event(:req, :t_discon, %F{}, %S{})
    assert :e16 == get_event(:timeout, :connection, %F{}, %S{})
    # assert :e17 == get_event(:timeout, :ack, %F{rep: 2}, %S{})
    # assert :e18 == get_event(:timeout, :ack, %F{rep: 3}, %S{})
    # assert :e18 == get_event(:timeout, :ack, %F{rep: 4}, %S{})
    assert :e19 == get_event(:conf, :t_connect, %F{ok?: true}, %S{})
    assert :e20 == get_event(:conf, :t_connect, %F{ok?: false}, %S{})
    assert :e21 == get_event(:conf, :t_discon, %F{}, %S{})
    assert :e22 == get_event(:conf, :t_data_con, %F{}, %S{})
    assert :e23 == get_event(:conf, :t_ack, %F{}, %S{})
    assert :e24 == get_event(:conf, :t_nak, %F{}, %S{})
  end
end
