defmodule Knx.Knxnetip.ConTab do
  alias Knx.Knxnetip.Connection, as: C

  def open(con_tab, con_type, data_endpoint) do
    con_tab = Map.put_new(con_tab, :free_ids, Enum.to_list(0..255))
    free_ids = con_tab[:free_ids]

    case List.pop_at(free_ids, 0) do
      {nil, _free_ids} ->
        {con_tab, {:error, :no_more_connections}}

      {new_id, free_ids} ->
        new_connection = %C{
          id: new_id,
          con_type: con_type,
          dest_data_endpoint: data_endpoint,
          ext_seq_counter: 0,
          int_seq_counter: 0
        }

        con_tab = Map.put_new(con_tab, new_id, new_connection)
        con_tab = put_in(con_tab[:free_ids], free_ids)
        {con_tab, new_id}
    end
  end

  def is_open?(con_tab, id) do
    Map.has_key?(con_tab, id)
  end

  def check_connection(con_tab, id) do
    case Map.has_key?(con_tab, id) do
      true -> :ok
      false -> {:error, id}
    end
  end

  def increment_ext_seq_counter(con_tab, id) do
    cur_count = con_tab[id].ext_seq_counter
    <<new_count>> = <<cur_count + 1::8>>
    put_in(con_tab[id].ext_seq_counter, new_count)
  end

  def increment_int_seq_counter(con_tab, id) do
    cur_count = con_tab[id].int_seq_counter
    <<new_count>> = <<cur_count + 1::8>>
    put_in(con_tab[id].int_seq_counter, new_count)
  end

  def ext_seq_counter_equal?(con_tab, id, counter) do
    counter == con_tab[id].ext_seq_counter
  end

  def int_seq_counter_equal?(con_tab, id, counter) do
    counter == con_tab[id].int_seq_counter
  end

  def get_int_seq_counter(con_tab, id) do
    con_tab[id].int_seq_counter
  end

  # def get_ext_seq_counter(con_tab, id) do
  #   if is_open?(con_tab, id) do
  #     con_tab[id].ext_seq_counter
  #   else
  #     {:error, :connection_id}
  #   end
  # end

  def get_data_endpoint(con_tab, id) do
    con_tab[id].dest_data_endpoint
  end

  def close(con_tab, id) do
    case Map.pop(con_tab, id) do
      {nil, con_tab} ->
        {con_tab, {:error, :connection_id}}

      {_id, con_tab} ->
        {put_in(con_tab[:free_ids], [id | con_tab[:free_ids]]), id}
    end
  end
end
