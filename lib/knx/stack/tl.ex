defmodule Knx.Stack.Tl do
  import PureLogger
  alias Knx.State, as: S
  alias Knx.Frame, as: F
  alias Knx.Ail.AddrTab
  require Knx.Defs
  import Knx.Defs

  def handle(
        {:tl, :req, %F{service: service, data: data, seq: seq, tsap: tsap, dest: dest} = frame},
        %S{}
      ) do
    case encode(service, seq, tsap) do
      {:error, reason} ->
        error({reason, frame})

      {addr_t, tpci, tsap} ->
        dest = get_dest(addr_t, tsap, dest)
        data = <<tpci::bits, data::bits>>
        [{:nl, :req, %F{frame | dest: dest, addr_t: addr_t, data: data}}]
    end
  end

  def handle(
        {:tl, up_prim, %F{data: data, addr_t: addr_t, dest: dest} = frame},
        %S{}
      ) do
    case decode(addr_t, dest, data) do
      {:error, reason} ->
        warning({reason, frame})

      {service, seq, data} ->
        tsap = get_tsap(addr_t, dest)
        [{:tlsm, up_prim, %F{frame | service: service, data: data, seq: seq, tsap: tsap}}]
    end
  end

  # ---------------------------------------------------------------------------

  defp get_tsap(addr_t(:ind), _), do: nil
  defp get_tsap(addr_t(:grp), dest), do: AddrTab.get_tsap(dest)
  defp get_dest(addr_t(:ind), _, dest), do: dest
  defp get_dest(addr_t(:grp), 0, _), do: 0
  defp get_dest(addr_t(:grp), tsap, _), do: AddrTab.get_group_addr(tsap)

  defp decode(addr_t(:ind), _dest, data) do
    case data do
      <<0::6, data::bits>> ->
        {:t_data_ind, nil, data}

      <<0b01::2, seq::4, data::bits>> ->
        {:t_data_con, seq, data}

      <<0b1000_0000::8>> ->
        {:t_connect, nil, <<>>}

      <<0b1000_0001::8>> ->
        {:t_discon, nil, <<>>}

      <<0b11::2, seq::4, 0b10::2>> ->
        {:t_ack, seq, <<>>}

      <<0b11::2, seq::4, 0b11::2>> ->
        {:t_nak, seq, <<>>}

      _ ->
        {:error, {:invalid_tpci, inspect(data, base: :hex)}}
    end
  end

  defp decode(addr_t(:grp), dest, data) do
    case {dest, data} do
      {0, <<0::6, data::bits>>} -> {:t_data_broadcast, nil, data}
      {_, <<0::6, data::bits>>} -> {:t_data_group, nil, data}
      {_, <<1::6, data::bits>>} -> {:t_data_tag_group, nil, data}
      _ -> {:error, {:invalid_tpci, inspect(data, base: :hex)}}
    end
  end

  defp encode(service, seq, tsap) do
    case service do
      :t_data_group -> {addr_t(:grp), <<0::6>>, tsap}
      :t_data_broadcast -> {addr_t(:grp), <<0::6>>, 0}
      :t_data_tag_group -> {addr_t(:grp), <<0b00_0001::6>>, tsap}
      :t_data_ind -> {addr_t(:ind), <<0::6>>, tsap}
      :t_data_con -> {addr_t(:ind), <<0b01::2, seq::4>>, tsap}
      :t_connect -> {addr_t(:ind), <<0b1000_0000::8>>, tsap}
      :t_discon -> {addr_t(:ind), <<0b1000_0001::8>>, tsap}
      :t_ack -> {addr_t(:ind), <<0b11::2, seq::4, 0b10::2>>, tsap}
      :t_nak -> {addr_t(:ind), <<0b11::2, seq::4, 0b11::2>>, tsap}
      _ -> {:error, :invalid_service}
    end
  end
end
