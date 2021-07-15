defmodule Knx.Ail.GoServer do
  alias Knx.Ail.{AssocTab, GoTab}
  alias Knx.Frame, as: F
  alias Knx.State, as: S
  alias Knx.State.GoServer, as: GOSS

  def handle(impulse, %S{go_server: go_server} = state) do
    %GOSS{impulses: impulses, values: values} =
      go_server = handle_(impulse, %GOSS{go_server | values: Cache.get(:go_values)})

    Cache.put(:go_values, values)

    {%S{state | go_server: %GOSS{go_server | impulses: []}}, impulses}
  end

  # ----------------------------------------------------------------------------

  defp handle_(
         {:go, :req, %F{apci: :group_read, asap: asap} = frame},
         %GOSS{} = state
       ) do
    case get_first(:transmits, asap: asap) do
      {:ok, {tsap, _}} ->
        transmit(state, {:al, :req, %F{frame | tsap: tsap}})

      :error ->
        state
    end
  end

  defp handle_(
         {:go, :req, %F{apci: :group_write, asap: asap, data: value} = frame},
         %GOSS{} = state
       ) do
    case get_first(:transmits, asap: asap) do
      {:ok, {tsap, _}} ->
        state
        |> update_tsap(tsap, value)
        |> transmit({:al, :req, %F{frame | tsap: tsap, data: value}})

      :error ->
        state
    end
  end

  defp handle_({:go, :ind, %F{apci: :group_read, tsap: tsap}}, %GOSS{values: values} = state) do
    case get_first(:readable, tsap: tsap) do
      {:ok, {_, go}} ->
        {:ok, {resp_tsap, _}} = get_first(:readable, asap: go.asap)
        # HACK was ist default? -- so ist jedenfalls falsch da groesse nicht beruecksichtigt.
        # go_value = Map.fetch!(values, go.asap)
        go_value = Map.get(values, go.asap, [<<0::6>>])

        state
        |> update_tsap(resp_tsap, go_value)
        |> transmit(
          {:al, :req,
           %F{apci: :group_resp, tsap: resp_tsap, data: go_value, service: :t_data_group}}
        )

      :error ->
        state
    end
  end

  defp handle_({:go, :ind, %F{apci: :group_write, tsap: tsap, data: value}}, %GOSS{} = state),
    do: update_tsap(state, tsap, value, :writable)

  defp handle_({:go, :ind, %F{apci: :group_resp, tsap: tsap, data: value}}, %GOSS{} = state),
    do: update_tsap(state, tsap, value, :updatable)

  defp handle_({:go, :conf, %F{}}, %GOSS{} = state),
    do: transmit(state, :recall)

  defp transmit(%GOSS{deferred: []} = state, :recall),
    do: %GOSS{state | transmitting: false}

  defp transmit(%GOSS{impulses: impulses, deferred: [impulse | deferred]} = state, :recall),
    do: %GOSS{state | transmitting: true, deferred: deferred, impulses: impulses ++ [impulse]}

  defp transmit(%GOSS{transmitting: true, deferred: deferred} = state, impulse),
    do: %GOSS{state | deferred: deferred ++ [impulse]}

  defp transmit(%GOSS{transmitting: false, impulses: impulses} = state, impulse),
    do: %GOSS{state | transmitting: true, impulses: impulses ++ [impulse]}

  defp udapte_go(%GOSS{impulses: impulses, values: values} = state, go, value) do
    state
    |> Map.put(:values, Map.put(values, go.asap, value))
    |> Map.put(:impulses, impulses ++ [{:app, :go_value, {go.asap, value}}])
  end

  defp update_tsap(state, tsap, value, flag \\ :any) do
    AssocTab.get_assocs(tsap: tsap)
    |> GoTab.get_all(flag)
    |> Enum.reduce(state, fn {_, go}, state -> udapte_go(state, go, value) end)
  end

  def get_first(flag, selector) do
    AssocTab.get_assocs(selector) |> GoTab.get_first(flag)
  end
end
