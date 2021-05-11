defmodule Cache do
  use Agent

  defp via() do
    case Process.whereis(:cache_registry) do
      nil -> __MODULE__
      _ -> {:via, Registry, {:cache_registry, Process.get(:cache_id)}}
    end
  end

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: via())
  end

  def get(key) do
    Agent.get(via(), &Map.get(&1, key))
  end

  def put(key, value) do
    Agent.update(via(), &Map.put(&1, key, value))
    value
  end

  def update(key, update_fn) do
    value = get(key)
    value = update_fn.(value)
    put(key, value)
  end
end
