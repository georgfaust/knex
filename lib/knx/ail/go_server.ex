defmodule Knx.Ail.GoServer do
  alias Knx.Ail.{AssocTab, GoTab}
  alias Knx.Frame, as: F

  defstruct values: %{},
            deferred: [],
            impulses: [],
            transmitting: false

  @me __MODULE__

  def handle(impulse, context) do
    %@me{impulses: impulses} = state = handle_(impulse, context)
    {%@me{state | impulses: []}, impulses}
  end

  # ----------------------------------------------------------------------------

  defp handle_(
         {:go, :req, %F{apci: :group_read, asap: asap} = frame},
         {assoc_tab, go_tab, %@me{} = state}
       ) do
    case get_first(assoc_tab, go_tab, :transmits, asap: asap) do
      {:ok, {tsap, _}} ->
        transmit(state, {:al, :req, %F{frame | tsap: tsap}})

      :error ->
        state
    end
  end

  defp handle_(
         {:go, :req, %F{apci: :group_write, asap: asap, data: value} = frame},
         {assoc_tab, go_tab, %@me{} = state}
       ) do
    case get_first(assoc_tab, go_tab, :transmits, asap: asap) do
      {:ok, {tsap, _}} ->
        state
        |> update_tsap(assoc_tab, go_tab, tsap, value)
        |> transmit({:al, :req, %F{frame | tsap: tsap, data: value}})

      :error ->
        state
    end
  end

  defp handle_(
         {:go, :ind, %F{apci: :group_read, tsap: tsap}},
         {assoc_tab, go_tab, %@me{values: values} = state}
       ) do
    case get_first(assoc_tab, go_tab, :readable, tsap: tsap) do
      {:ok, {_, go}} ->
        {:ok, {resp_tsap, _}} = get_first(assoc_tab, go_tab, :readable, asap: go.asap)
        go_value = Map.get(values, go.asap, 0)

        state
        |> update_tsap(assoc_tab, go_tab, resp_tsap, go_value)
        |> transmit({:al, :req, %F{apci: :group_resp, tsap: resp_tsap, data: go_value}})

      :error ->
        state
    end
  end

  defp handle_(
         {:go, :ind, %F{apci: :group_write, tsap: tsap, data: value}},
         {assoc_tab, go_tab, %@me{} = state}
       ),
       do: update_tsap(state, assoc_tab, go_tab, tsap, value, :writable)

  defp handle_(
         {:go, :ind, %F{apci: :group_resp, tsap: tsap, data: value}},
         {assoc_tab, go_tab, %@me{} = state}
       ),
       do: update_tsap(state, assoc_tab, go_tab, tsap, value, :updatable)

  defp handle_(
         {:go, :conf, %F{}},
         {_assoc_tab, _go_tab, %@me{} = state}
       ),
       do: transmit(state, :recall)

  defp transmit(%@me{deferred: []} = state, :recall),
    do: %@me{state | transmitting: false}

  defp transmit(%@me{impulses: impulses, deferred: [impulse | deferred]} = state, :recall),
    do: %@me{state | transmitting: true, deferred: deferred, impulses: impulses ++ [impulse]}

  defp transmit(%@me{transmitting: true, deferred: deferred} = state, impulse),
    do: %@me{state | deferred: deferred ++ [impulse]}

  defp transmit(%@me{transmitting: false, impulses: impulses} = state, impulse),
    do: %@me{state | transmitting: true, impulses: impulses ++ [impulse]}

  defp udapte_go(%@me{impulses: impulses, values: values} = state, go, value) do
    state
    |> Map.put(:values, Map.put(values, go.asap, value))
    |> Map.put(:impulses, impulses ++ [{:user, :go_value, {go.asap, value}}])
  end

  defp update_tsap(state, assoc_tab, go_tab, tsap, value, flag \\ :any) do
    assoc_tab
    |> AssocTab.get_assocs(tsap: tsap)
    |> GoTab.get_all(go_tab, flag)
    |> Enum.reduce(state, fn {_, go}, state -> udapte_go(state, go, value) end)
  end

  def get_first(assoc_tab, go_tab, flag, selector) do
    assoc_tab
    |> AssocTab.get_assocs(selector)
    |> GoTab.get_first(go_tab, flag)
  end
end
