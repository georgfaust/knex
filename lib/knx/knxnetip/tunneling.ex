defmodule Knx.Knxnetip.Tunneling do
  alias Knx.Knxnetip.IPFrame
  alias Knx.Knxnetip.CEMIFrame
  alias Knx.Knxnetip.ConTab

  require Knx.Defs
  import Knx.Defs

  def handle_body(
        _src,
        %IPFrame{service_type_id: service_type_id(:tunnelling_req)} = ip_frame,
        <<
          structure_length(:connection_header)::8,
          channel_id::8,
          ext_seq_counter::8,
          knxnetip_constant(:reserved)::8,
          cemi_message_code::8,
          # additional information: none
          0::8,
          frame_type::2,
          # TODO 1 means, DL repetitions may be sent. how to handle this?
          repeat::1,
          _system_broadcast::1,
          prio::2,
          # TODO for TP1, L2-Acks are requested independent of value
          _ack::1,
          _confirm::1,
          addr_t::1,
          hops::3,
          eff::4,
          src_addr::16,
          dest_addr::16,
          len::8,
          data::bits
        >>
      ) do
    con_tab = Cache.get(:con_tab)

    # TODO how does the server react if no connection is open? (not specified)
    if ConTab.is_open?(con_tab, channel_id) do
      cemi_frame = %CEMIFrame{
        message_code: cemi_message_code,
        frame_type: frame_type,
        repeat: repeat,
        prio: prio,
        addr_t: addr_t,
        hops: hops,
        eff: eff,
        src: src_addr,
        dest: dest_addr,
        len: len,
        data: data
      }

      ip_frame = %{
        ip_frame
        | channel_id: channel_id,
          ext_seq_counter: ext_seq_counter,
          data_endpoint: ConTab.get_data_endpoint(con_tab, channel_id),
          cemi: cemi_frame
      }

      cond do
        ConTab.ext_seq_counter_equal?(con_tab, channel_id, ext_seq_counter) ->
          con_tab = ConTab.increment_ext_seq_counter(con_tab, channel_id)
          Cache.put(:con_tab, con_tab)

          [tunneling_ack(ip_frame), {:dl, :req, ip_frame.cemi}]

        ConTab.ext_seq_counter_equal?(con_tab, channel_id, ext_seq_counter - 1) ->
          ip_frame = %{
            ip_frame
            | ext_seq_counter: ext_seq_counter - 1
          }

          [tunneling_ack(ip_frame)]

        true ->
          []
      end
    else
      []
    end
  end

  # ----------------------------------------------------------------------------

  defp tunneling_ack(%IPFrame{
         channel_id: channel_id,
         ext_seq_counter: ext_seq_counter,
         data_endpoint: data_endpoint
       }) do
    frame = <<
      structure_length(:header)::8,
      protocol_version(:knxnetip)::8,
      service_type_id(:tunnelling_ack)::16,
      structure_length(:tunneling_ack)::16,
      structure_length(:connection_header)::8,
      channel_id::8,
      ext_seq_counter::8,
      tunneling_ack_status_code(:no_error)::8
    >>

    {:ethernet, :transmit, {data_endpoint, frame}}
  end
end
