defmodule Knx.Knxnetip.ConTab do
  alias Knx.Knxnetip.Connection, as: C

  def open(con_tab, con_type, data_endpoint) do
    # add once, when first connection is opened
    con_tab = Map.put_new(con_tab, :free_mgmt_ids, Enum.to_list(0..254))
    free_mgmt_ids = con_tab[:free_mgmt_ids]

    new_connection = %C{
      con_type: con_type,
      dest_data_endpoint: data_endpoint,
      ext_seq_counter: 0,
      int_seq_counter: 0
    }

    case con_type do
      # allow only one open tunneling connection (always has id 255)
      # TODO allow multiple tunneling connections ?
      :tunnel_con ->
        if is_open?(con_tab, 255) do
          {con_tab, {:error, :no_more_connections}}
        else
          new_connection = %C{new_connection | id: 255}
          con_tab = Map.put_new(con_tab, 255, new_connection)
          {con_tab, 255}
        end

      :device_mgmt_con ->
        case List.pop_at(free_mgmt_ids, 0) do
          {nil, _free_mgmt_ids} ->
            {con_tab, {:error, :no_more_connections}}

          {new_id, free_mgmt_ids} ->
            new_connection = %C{new_connection | id: new_id}

            con_tab = Map.put_new(con_tab, new_id, new_connection)
            con_tab = put_in(con_tab[:free_mgmt_ids], free_mgmt_ids)
            {con_tab, new_id}
        end
    end
  end

  def is_open?(con_tab, id) do
    Map.has_key?(con_tab, id)
  end

  # def check_connection(con_tab, id) do
  #   case Map.has_key?(con_tab, id) do
  #     true -> :ok
  #     false -> {:error, id}
  #   end
  # end

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

      {id, con_tab} ->
        if id == 255 do
          {con_tab, 255}
        else
          {put_in(con_tab[:free_mgmt_ids], [id | con_tab[:free_mgmt_ids]]), id}
        end
    end
  end
end
