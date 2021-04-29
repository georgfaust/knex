defmodule Knx.Stack.Tlsm.Event do
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  def get_event(:ind, :t_connect, %F{src: addr}, %S{c_addr: addr}), do: :e00
  def get_event(:ind, :t_connect, _, _), do: :e01

  def get_event(:ind, :t_discon, %F{src: addr}, %S{c_addr: addr}), do: :e02
  def get_event(:ind, :t_discon, _, _), do: :e03

  def get_event(:ind, :t_data_con, %F{src: addr, seq: seq}, %S{c_addr: addr, r_seq: r_seq}) do
    use Bitwise

    cond do
      seq == r_seq -> :e04
      seq == (r_seq - 1 &&& 0xF) -> :e05
      seq != r_seq -> :e06
    end
  end

  def get_event(:ind, :t_data_con, _, _), do: :e07

  def get_event(:ind, :t_ack, %F{src: addr, seq: seq}, %S{c_addr: addr, s_seq: seq}), do: :e08
  def get_event(:ind, :t_ack, %F{src: addr}, %S{c_addr: addr}), do: :e09
  def get_event(:ind, :t_ack, %F{}, %S{}), do: :e10

  def get_event(:ind, :t_nak, %F{src: addr, seq: seq}, %S{c_addr: addr, s_seq: seq, rep: rep}) do
    case max_repeat_reached?(rep) do
      true -> :e13
      _ -> :e12
    end
  end

  def get_event(:ind, :t_nak, %F{src: addr}, %S{c_addr: addr}), do: :e11
  def get_event(:ind, :t_nak, %F{}, %S{}), do: :e14

  def get_event(:req, :t_data_con, %F{}, %S{}), do: :e15
  def get_event(:req, :t_connect, %F{}, %S{}), do: :e25
  def get_event(:req, :t_discon, %F{}, %S{}), do: :e26

  def get_event(:conf, :t_connect, %F{ok?: true}, %S{}), do: :e19
  def get_event(:conf, :t_connect, %F{ok?: false}, %S{}), do: :e20
  def get_event(:conf, :t_discon, %F{}, %S{}), do: :e21
  def get_event(:conf, :t_data_con, %F{}, %S{}), do: :e22
  def get_event(:conf, :t_ack, %F{}, %S{}), do: :e23
  def get_event(:conf, :t_nak, %F{}, %S{}), do: :e24

  def get_event(:timeout, :connection, %F{}, %S{}), do: :e16

  def get_event(:timeout, :ack, %F{}, %S{rep: rep}) do
    case max_repeat_reached?(rep) do
      true -> :e18
      _ -> :e17
    end
  end

  # ---------------------------------------------------------------
  defp max_repeat_reached?(rep), do: rep >= 3
end
