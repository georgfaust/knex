defmodule Knx.Stack.Dl do
  @std 0b10
  @ext 0b00

  alias Knx.State, as: S
  alias Knx.Frame, as: F

  # @spec handle(Knx.impulse_t(), S.t()) :: [Knx.impulse_t()]

  def handle({:dl, :req, %F{data: data} = frame}, %S{}),
    do: [{:driver, :transmit, frame(frame, byte_size(data) - 1)}]

  def handle({:dl, :ind, frame}, %S{}), do: handle_(:ind, nil, frame)
  def handle({:dl, :conf, frame}, %S{}), do: handle_(:conf, true, frame)
  def handle({:dl, :conf_error, frame}, %S{}), do: handle_(:conf, false, frame)

  # ----------------------------------------

  defp handle_(prim, ok?, <<@std::2, ctrl1::6, addrs::32, ctrl2::4, len::4, data::bits>>) do
    handle_(prim, ok?, <<@ext::2, ctrl1::6, ctrl2::4, 0::4, addrs::32, 0::4, len::4, data::bits>>)
  end

  defp handle_(
         prim,
         ok?,
         <<
           @ext::2,
           # TODO
           _repeat::1,
           1::1,
           prio::2,
           0::2,
           addr_t::1,
           hops::3,
           eff::4,
           src::16,
           dest::16,
           len::8,
           data::bits
         >>
       ) do
    frame = %F{
      addr_t: addr_t,
      src: src,
      dest: dest,
      prio: prio,
      hops: hops,
      len: len,
      data: data,
      eff: eff,
      ok?: ok?
    }

    [{:nl, prim, frame}]
  end

  defp frame(%F{data: data, prio: p, src: s, dest: d, addr_t: addr_t, hops: hops}, len)
       when len <= 15 do
    <<@std::2, 3::2, p::2, 0::2, s::16, d::16, addr_t::1, hops::3, len::4, data::bits>>
  end

  defp frame(
         %F{data: data, prio: p, src: s, dest: d, addr_t: addr_t, hops: hops, eff: eff},
         len
       ) do
    <<@ext::2, 1::2, p::2, 0::2, addr_t::1, hops::3, eff::4, s::16, d::16, len::8, data::bits>>
  end
end
