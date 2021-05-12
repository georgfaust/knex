defmodule Knx.Ail.Lsm do
  require Knx.Defs
  import Knx.Defs

  def init(), do: load_state(:unloaded)

  def dispatch(load_state, {event, data}) do
    case {load_state, event} do
      {load_state(:loading), load_event(:load_completed)} ->
        {load_state(:loaded), nil}

      {load_state(:loading), load_event(:additional_lc)} ->
        {load_state(:loading), decode_le(data)}

      {_, load_event(:start_loading)} ->
        {load_state(:loading), nil}

      {_, load_event(:unload)} ->
        {load_state(:unloaded), nil}

      {_, load_event(:noop)} ->
        {load_state, nil}
    end
  end

  def encode_le(:alc_data_rel_alloc, [req_mem_size, mode, fill]) do
    <<load_event(:additional_lc)::8, additional_lc(:data_rel_alloc)::8, req_mem_size::32, 0::7,
      mode::1, fill::8, 0::16>>
  end

  def encode_le(le) do
    case le do
      :noop -> <<load_event(:noop)::8, 0::unit(8)-9>>
      :start_loading -> <<load_event(:start_loading)::8, 0::unit(8)-9>>
      :load_completed -> <<load_event(:load_completed)::8, 0::unit(8)-9>>
      :additional_lc -> raise("additional_lc encoder missing")
      :unload -> <<load_event(:unload)::8, 0::unit(8)-9>>
    end
  end

  # ------------------------------

  defp decode_le(
         <<additional_lc(:data_rel_alloc)::8, req_mem_size::32, _::7, mode::1, fill::8, _::16>>
       ) do
    {:alc_data_rel_alloc, [req_mem_size, mode, fill]}
  end

  defp decode_le(data), do: {:error, :unhandled_load_event, data}
end
