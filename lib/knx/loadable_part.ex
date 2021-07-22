defmodule Knx.LoadablePart do
  @callback decode(mem :: binary()) :: any()
  @callback load_complete() :: any()

  @optional_callbacks load_complete: 0

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Knx.LoadablePart

      @object_type Keyword.fetch!(opts, :object_type)
      @mem_size Keyword.fetch!(opts, :mem_size)
      @unloaded_mem Keyword.fetch!(opts, :unloaded_mem)

      alias Knx.Ail.Property, as: P

      require Knx.Defs
      import Knx.Defs

      def load_complete(), do: {:ok, []}
      defoverridable load_complete: 0

      def load() do
        Cache.get_obj(@object_type)
        |> P.read_prop_value(:table_reference)
        |> Knx.Mem.read(@mem_size)
        |> case do
          {:ok, mem} ->
            {:ok, Cache.put(@object_type, decode(mem))}
            load_complete()

          error ->
            error
        end
      end

      def unload() do
        Cache.put(@object_type, @unloaded_mem)
        {:ok, []}
      end

      def load_ctrl(%{values: [load_state]}, [{event, data}]) do
        {new_load_state, additional_load_control} =
          Knx.Ail.Lsm.dispatch(load_state, {event, data})

        case additional_load_control do
          nil ->
            nil

          {:alc_data_rel_alloc, [_req_mem_size, _mode, _fill]} ->
            # TODO additional_load_control alc_data_rel_alloc not implemented"
            nil

          additional_load_control ->
            raise("unknown additional_load_control: #{inspect(additional_load_control)}")
        end

        case new_load_state_action(new_load_state) do
          {:ok, impulses} -> {:ok, [new_load_state], impulses}
          {:error, _} -> {:error, [load_state(:error)]}
          unexpected -> raise(inspect({:unexpected, unexpected}))
        end
      end

      # ---

      defp new_load_state_action(new_load_state) do
        case new_load_state do
          load_state(:unloaded) -> unload()
          load_state(:loaded) -> load()
          _ -> {:ok, []}
        end
      end
    end
  end
end
