def event(:ind, :t_connect, %F{src: addr}, %S{c_addr: addr}), do: :e00
def event(:ind, :t_connect, _, _), do: :e01

def event(:ind, :t_discon, %F{src: addr}, %S{c_addr: addr}), do: :e02
def event(:ind, :t_discon, _, _), do: :e03

def event(:ind, :t_data_con, %F{src: addr, seq: seq}, %S{c_addr: addr, r_seq: r_seq}) do
  use Bitwise

  cond do
    seq == r_seq -> :e04
    seq == (con_seq - 1 &&& 0xF) -> :e05
    seq != r_seq -> :e06
  end
end

def event(:ind, :t_data_con, _, _), do: :e07

def event(:ind, :t_ack, %F{src: addr, seq: seq}, %S{c_addr: addr, r_seq: seq}), do: :e08
def event(:ind, :t_ack, %F{src: addr}, %S{c_addr: addr}), do: :e09
def event(:ind, :t_ack, %F{}, %S{}), do: :e10

def event(:ind, :t_nak, %F{src: addr, seq: seq, rep: rep}, %S{c_addr: addr, r_seq: seq}) do
  case max_repeat_reached?(rep) do
    true -> :e13
    _ -> :e12
  end
end

def event(:ind, :t_ack, %F{src: addr}, %S{c_addr: addr}), do: :e11
def event(:ind, :t_ack, %F{}, %S{}), do: :e14

def event(:ind, :t_data_con, %F{}, %S{}), do: :e15
def event(:ind, :t_connect, %F{}, %S{}), do: :e25
def event(:ind, :t_discon, %F{}, %S{}), do: :e26

def event(:conf, :t_connect, %F{ok?: true}, %S{}), do: :e19
def event(:conf, :t_connect, %F{ok?: false}, %S{}), do: :e20
def event(:conf, :t_discon, %F{}, %S{}), do: :e21
def event(:conf, :t_data_con, %F{}, %S{}), do: :e22
def event(:conf, :t_ack, %F{}, %S{}), do: :e23
def event(:conf, :t_nak, %F{}, %S{}), do: :e24

def event(:timeout, :connection, %F{}, %S{}), do: :e16

def event(:timeout, :ack, %F{}, %S{}) do
  case max_repeat_reached?(rep) do
    true -> :e18
    _ -> :e17
  end
end

defp max_repeat_reached?(rep), do: rep >= 3
