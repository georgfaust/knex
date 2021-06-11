defmodule Knx.Knxnetip.ConTab do
  alias Knx.Knxnetip.Connection, as: C
  alias Knx.Knxnetip.IPFrame

  def open(con_tab, con_type, %IPFrame{} = ip_frame) do
    # add once, when first connection is opened
    con_tab = Map.put_new(con_tab, :free_mgmt_ids, Enum.to_list(0..254))
    free_mgmt_ids = con_tab[:free_mgmt_ids]

    new_connection = %C{
      con_type: con_type,
      dest_control_endpoint: ip_frame.control_endpoint,
      dest_data_endpoint: ip_frame.data_endpoint,
      client_seq_counter: 0,
      server_seq_counter: 0
    }

    case con_type do
      # allows only one open tunnelling connection (always has id 255)
      # TODO allow multiple tunnelling connections ?
      :tunnel_con ->
        if is_open?(con_tab, 255) do
          {con_tab, {:error, :no_more_connections}}
        else
          new_connection = %C{new_connection | id: 255}
          con_tab = Map.put_new(con_tab, 255, new_connection)
          {:ok, con_tab, 255}
        end

      :device_mgmt_con ->
        case List.pop_at(free_mgmt_ids, 0) do
          {nil, _free_mgmt_ids} ->
            {con_tab, {:error, :no_more_connections}}

          {new_id, free_mgmt_ids} ->
            new_connection = %C{new_connection | id: new_id}

            con_tab = Map.put_new(con_tab, new_id, new_connection)
            con_tab = put_in(con_tab[:free_mgmt_ids], free_mgmt_ids)
            {:ok, con_tab, new_id}
        end
    end
  end

  def is_open?(con_tab, id) do
    Map.has_key?(con_tab, id)
  end

  # !info: is this necessary? without checking the source data ep, knowing the
  #  channel id (only applies for device management)
  #  and sequence counter is enough to hijack the connection
  def check_access(con_tab, id, src_data_endpoint) do
    if Map.has_key?(con_tab, id) do
      if con_tab[id].dest_data_endpoint == src_data_endpoint do
        :ok
      else
        {:error, :access_forbidden}
      end
    else
      {:error, :connection_id}
    end
  end

  def increment_client_seq_counter(con_tab, id) do
    cur_count = con_tab[id].client_seq_counter
    <<new_count>> = <<cur_count + 1::8>>
    put_in(con_tab[id].client_seq_counter, new_count)
  end

  def increment_server_seq_counter(con_tab, id) do
    cur_count = con_tab[id].server_seq_counter
    <<new_count>> = <<cur_count + 1::8>>
    put_in(con_tab[id].server_seq_counter, new_count)
  end

  def client_seq_counter_equal?(con_tab, id, counter) do
    counter == con_tab[id].client_seq_counter
  end

  def server_seq_counter_equal?(con_tab, id, counter) do
    counter == con_tab[id].server_seq_counter
  end

  def get_server_seq_counter(con_tab, id) do
    con_tab[id].server_seq_counter
  end

  def get_client_seq_counter(con_tab, id) do
    con_tab[id].client_seq_counter
  end

  def get_control_endpoint(con_tab, id) do
    con_tab[id].dest_control_endpoint
  end

  def get_data_endpoint(con_tab, id) do
    con_tab[id].dest_data_endpoint
  end

  def close(con_tab, id) do
    case Map.pop(con_tab, id) do
      {nil, _con_tab} ->
        {:error, :connection_id}

      {id, con_tab} ->
        if id == 255 do
          {:ok, con_tab, 255}
        else
          {:ok, put_in(con_tab[:free_mgmt_ids], [id | con_tab[:free_mgmt_ids]]), id}
        end
    end
  end
end
