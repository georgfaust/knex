defmodule Knx.DataCemiFrame do
  require Knx.Defs
  import Knx.Defs

  alias Knx.Frame, as: F
  alias Knx.KnxnetIp.KnxnetIpParameter

  def decode(<<
        mc::8,
        # --- additional info len - not implemented, expect always 0
        0::8,

        # --- Ctrl1
        frame_type::1,
        0::1,
        # TODO 1 means, DL repetitions may be sent. how do we handle this? (03_06_03:4.1.5.3.3)
        repeat::1,
        # !info: don't care (03_06_03:4.1.5.3.3)
        _system_broadcast::1,
        prio::2,
        # TODO for TP1, L2-Acks are requested independent of value
        _ack::1,
        confirm::1,

        # Ctrl2
        addr_t::1,
        hops::3,
        0::4,
        src_addr::16,
        dest_addr::16,
        len::8,
        data::bits
      >>)
      when mc in [
             cemi_message_code(:l_data_ind),
             cemi_message_code(:l_data_con)
           ] do
    primitive =
      case mc do
        cemi_message_code(:l_data_ind) -> :ind
        cemi_message_code(:l_data_con) -> :conf
      end

    frame = %F{
      message_code: mc,
      frame_type: frame_type,
      repeat: repeat,
      confirm: confirm,
      prio: prio,
      addr_t: addr_t,
      hops: hops,
      src: src_addr,
      dest: dest_addr,
      len: len,
      data: data
    }

    {primitive, frame}
  end

  def decode(_), do: {nil, nil}

  def encode(primitive, %F{
        prio: prio,
        addr_t: addr_t,
        src: src,
        dest: dest,
        data: data,
        hops: hops,
        confirm: confirm
      }) do
    # TODO stimmt das so?
    # repeat, system_broadcast and ack bits are not interpreted by client and therefore set to 0
    repeat = ack = 0
    system_broadcast = 1 # TODO ???
    len = byte_size(data) - 1
    frame_type = if(len <= 15, do: 1, else: 0)

    <<
      cemi_message_code2(primitive)::8,
      0::8,
      frame_type::1,
      0::1,
      repeat::1,
      system_broadcast::1,
      prio::2,
      ack::1,
      confirm::1,
      addr_t::1,
      hops::3,
      0::4,
      # TODO add check_src_addr
      check_src_addr(src)::16,
      dest::16,
      len::8,
      data::bits
    >>
  end

  # ----------------------------------------------------------------------------

  # def convert_to_req(<<_cemi_message_code::8, first_chunk::15, _confirm::1, rest::bits>>) do
  #   <<cemi_message_code(:l_data_req)::8, first_chunk::15, 0::1, rest::bits>>
  # end

  def convert_message_code(
        <<_cemi_message_code::8, first_chunk::15, _confirm::1, rest::bits>>,
        cemi_message_code
      ) do
    <<cemi_message_code(cemi_message_code)::8, first_chunk::15, 0::1, rest::bits>>
  end

  # [XXX]
  def check_src_addr(src) do
    # TODO if multiple individual addresses will be supported, src might not be replaced
    if src == 0 do
      KnxnetIpParameter.get_knx_indv_addr(Cache.get_obj(:knxnet_ip_parameter))
    else
      src
    end
  end
end
