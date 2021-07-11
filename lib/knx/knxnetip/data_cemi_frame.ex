defmodule Knx.KnxnetIp.DataCemiFrame do
  alias Knx.Frame, as: F
  alias Knx.KnxnetIp.KnxnetIpParameter, as: KnxnetIpParam

  require Knx.Defs
  import Knx.Defs

  defstruct message_code: nil,
            frame_type: nil,
            repeat: nil,
            confirm: 0,
            prio: nil,
            addr_t: nil,
            hops: nil,
            eff: 0,
            src: nil,
            dest: nil,
            len: nil,
            data: <<>>

  # ----------------------------------------------------------------------------

  def handle(<<
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
             cemi_message_code(:l_data_con),
             cemi_message_code(:l_data_req)
           ] do
    %__MODULE__{
      message_code: mc,
      frame_type: frame_type,
      repeat: repeat,
      confirm: confirm,
      prio: prio,
      addr_t: addr_t,
      hops: hops,
      src: check_src_addr(src_addr),
      dest: dest_addr,
      len: len,
      data: data
    }
  end

  def handle_knx_frame_struct(%F{
        prio: prio,
        addr_t: addr_t,
        hops: hops,
        src: src,
        dest: dest,
        len: len,
        data: data
      }) do
    %__MODULE__{
      message_code: cemi_message_code(:l_data_ind),
      frame_type: if(len <= 15, do: 1, else: 0),
      # TODO repeat, see 03_06_03:4.1.5.3.5
      repeat: 1,
      prio: prio,
      addr_t: addr_t,
      hops: hops,
      src: src,
      dest: dest,
      # TODO len ist hier noch nicht gesetzt, siehe unten
      len: len,
      data: data
    }
  end

  def handle_knx_frame_struct2(primitive, %F{
        prio: prio,
        addr_t: addr_t,
        hops: hops,
        src: src,
        dest: dest,
        data: data
      }) do
    len = byte_size(data) - 1

    %__MODULE__{
      message_code: cemi_message_code2(primitive),
      frame_type: if(len <= 15, do: 1, else: 0),
      # TODO repeat, see 03_06_03:4.1.5.3.5
      repeat: 1,
      prio: prio,
      addr_t: addr_t,
      hops: hops,
      src: src,
      dest: dest,
      len: len,
      data: data
    }
  end

  # ----------------------------------------------------------------------------

  def create(%__MODULE__{
        message_code: message_code,
        frame_type: frame_type,
        prio: prio,
        addr_t: addr_t,
        src: src,
        dest: dest,
        confirm: confirm,
        len: len,
        data: data
      }) do
    # repeat, system_broadcast and ack bits are not interpreted by client and therefore set to 0
    repeat = system_broadcast = ack = 0

    # TODO: does every knx frame get the hop count value 7?
    hops = 7

    <<
      message_code::8,
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
      check_src_addr(src)::16,
      dest::16,
      len::8,
      data::bits
    >>
  end

  def knx_frame_struct(%__MODULE__{
        message_code: mc,
        prio: prio,
        addr_t: addr_t,
        hops: hops,
        src: src,
        dest: dest,
        data: data,
        confirm: confirm
      }) do
    {ok?, _primitive} =
      case mc do
        cemi_message_code(:l_data_con) -> {if(confirm == 1, do: false, else: true), :conf}
        cemi_message_code(:l_data_ind) -> {nil, :ind}
        cemi_message_code(:l_data_req) -> {nil, :req}
      end

    %F{data: data, prio: prio, src: src, dest: dest, addr_t: addr_t, hops: hops, ok?: ok?}
  end

  def knx_frame_struct2(%__MODULE__{
        message_code: mc,
        prio: prio,
        addr_t: addr_t,
        hops: hops,
        src: src,
        dest: dest,
        data: data,
        confirm: confirm
      }) do
    {ok?, primitive} =
      case mc do
        cemi_message_code(:l_data_con) -> {if(confirm == 1, do: false, else: true), :conf}
        cemi_message_code(:l_data_ind) -> {nil, :ind}
        cemi_message_code(:l_data_req) -> {nil, :req}
      end

    {primitive,
     %F{data: data, prio: prio, src: src, dest: dest, addr_t: addr_t, hops: hops, ok?: ok?}}
  end

  # ----------------------------------------------------------------------------

  # [XXX]
  defp check_src_addr(src) do
    # TODO if multiple individual addresses will be supported, src might not be replaced
    if src == 0 do
      KnxnetIpParam.get_knx_indv_addr(Cache.get_obj(:knxnet_ip_parameter))
    else
      src
    end
  end
end
