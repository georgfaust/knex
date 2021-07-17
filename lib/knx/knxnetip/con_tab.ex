defmodule Knx.KnxnetIp.ConTab do
  alias Knx.KnxnetIp.Connection, as: C
  alias Knx.KnxnetIp.IpFrame

  def open(%{tunnel_cons_left: 0}, :tunnel_con, _ip_frame) do
    {:error, :no_more_connections}
  end

  def open(%{tunnel_cons_left: tunnel_cons_left} = con_tab, con_type, %IpFrame{} = ip_frame) do
    case List.pop_at(con_tab[:free_ids], 0) do
      {nil, _} ->
        {:error, :no_more_connections}

      {free_id, free_ids} ->
        new_connection = %C{
          id: free_id,
          con_type: con_type,
          dest_control_endpoint: ip_frame.control_endpoint,
          dest_data_endpoint: ip_frame.data_endpoint,
          client_seq_counter: 0,
          server_seq_counter: 0
        }

        con_tab = Map.put_new(con_tab, free_id, new_connection)
        con_tab = put_in(con_tab[:free_ids], free_ids)

        con_tab =
          if con_type == :tunnel_con do
            %{con_tab | tunnel_cons_left: tunnel_cons_left - 1}
          else
            con_tab
          end

        {:ok, con_tab, free_id}
    end
  end

  def open(%{} = con_tab, con_type, %IpFrame{} = ip_frame) do
    # initialize map on first call
    con_tab = Map.put_new(con_tab, :free_ids, Enum.to_list(0..255))
    # limit number of simultaneous tunnelling connections
    con_tab = Map.put_new(con_tab, :tunnel_cons_left, 1)

    open(con_tab, con_type, ip_frame)
  end

  def close(con_tab, id) do
    case Map.pop(con_tab, id) do
      {nil, _} ->
        {:error, :connection_id}

      {%C{con_type: con_type}, %{tunnel_cons_left: tunnel_cons_left} = con_tab} ->
        con_tab = Map.put(con_tab, :free_ids, [id | con_tab[:free_ids]])

        con_tab =
          if con_type == :tunnel_con do
            %{con_tab | tunnel_cons_left: tunnel_cons_left + 1}
          else
            con_tab
          end

        {:ok, con_tab}
    end
  end

  def is_open?(con_tab, id) do
    Map.has_key?(con_tab, id)
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
end
