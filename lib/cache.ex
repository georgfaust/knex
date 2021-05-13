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

  def get_obj(key) do
    objects = get(:objects)
    Keyword.get(objects, key)
  end

  def put_obj(key, props) do
    objects = get(:objects)
    objects = Keyword.put(objects, key, props)
    put(:objects, objects)
  end

  def update_obj(key, update_fn) do
    objects = get(:objects)
    objects = Keyword.update!(objects, key, update_fn)
    put(:objects, objects)
  end

  def get_obj_idx(idx) do
    {_, props} = Enum.at(get(:objects), idx, {nil, []})
    props
  end

  def put_obj_idx(idx, props) do
    objects = get(:objects)
    {object_t, _} = Enum.at(objects, idx)
    objects = List.replace_at(objects, idx, {object_t, props})
    put(:objects, objects)
  end
end
