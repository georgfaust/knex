defmodule Knx.Ail.Lsm do
  @load_state_unloaded 0
  @load_state_loaded 1
  @load_state_loading 2
  @load_state_error 3

  @noop 0
  @start_loading 1
  @load_completed 2
  @additional_lc 3
  @unload 4

  # @load_event_relative_allocation 0xA
  @le_data_rel_alloc 0xB

  def init(), do: @load_state_unloaded

  def dispatch(load_state, {event, data}) do
    case {load_state, event} do
      {@load_state_loading, @load_completed} -> {@load_state_loaded, nil}
      {@load_state_loading, @additional_lc} -> {@load_state_loading, decode_le(data)}
      {_, @start_loading} -> {@load_state_loading, nil}
      {_, @unload} -> {@load_state_unloaded, nil}
      {_, @noop} -> {load_state, nil}
    end
  end

  def encode_le(:le_data_rel_alloc, [req_mem_size, mode, fill]) do
    <<@additional_lc::8, @le_data_rel_alloc::8, req_mem_size::32, 0::7, mode::1, fill::8, 0::16>>
  end

  def encode_le(le) do
    case le do
      :noop -> <<@noop::8, 0::unit(8)-9>>
      :start_loading -> <<@start_loading::8, 0::unit(8)-9>>
      :load_completed -> <<@load_completed::8, 0::unit(8)-9>>
      :additional_lc -> raise("additional_lc encoder missing")
      :unload -> <<@unload::8, 0::unit(8)-9>>
    end
  end

  # ------------------------------

  defp decode_le(<<@le_data_rel_alloc::8, req_mem_size::32, _::7, mode::1, fill::8, _::16>>) do
    {:le_data_rel_alloc, [req_mem_size, mode, fill]}
  end

  defp decode_le(data), do: {:error, :unhandled_load_event, data}
end
