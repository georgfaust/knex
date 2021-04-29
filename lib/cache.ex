defmodule Cache do
  use Agent
  @me __MODULE__

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: @me)
  end

  def get(key) do
    Agent.get(@me, &Map.get(&1, key))
  end

  def put(key, value) do
    Agent.update(@me, &Map.put(&1, key, value))
    value
  end
end
