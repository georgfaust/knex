defmodule Knx.KnxnetIp.ConTab do
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.IpFrame

  def open(con_tab, con_type, %IpFrame{} = ip_frame) do
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
          {:error, :no_more_connections}
        else
          con_tab = Map.put_new(con_tab, 255, %C{new_connection | id: 255})
          {:ok, con_tab, 255}
        end

      :device_mgmt_con ->
        case List.pop_at(free_mgmt_ids, 0) do
          {nil, _free_mgmt_ids} ->
            {:error, :no_more_connections}

          {new_id, free_mgmt_ids} ->
            con_tab = Map.put_new(con_tab, new_id, %C{new_connection | id: new_id})
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
  # def check_access(con_tab, id, src_data_endpoint) do
  #   if Map.has_key?(con_tab, id) do
  #     if con_tab[id].dest_data_endpoint == src_data_endpoint do
  #       :ok
  #     else
  #       {:error, :access_forbidden}
  #     end
  #   else
  #     {:error, :connection_id}
  #   end
  # end

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

  def compare_client_seq_counter(con_tab, id, counter) do
    # seq_counter is 8-bit unsigned value
    <<incremented_counter>> = <<counter + 1>>

    cond do
      counter == con_tab[id].client_seq_counter ->
        :counter_equal
      incremented_counter == con_tab[id].client_seq_counter ->
        :counter_off_by_minus_one
      true ->
        :any_other_case
    end
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

      {_con, con_tab} ->
        if id == 255 do
          {:ok, con_tab}
        else
          {:ok, Map.put(con_tab, :free_mgmt_ids, [id | con_tab[:free_mgmt_ids]])}
        end
    end
  end
end
