defmodule Knx.Stack.Al do
  alias Knx.Frame, as: F
  require PureLogger
  require Knx.Defs
  import Knx.Defs

  import Knx.Toolbox

  # --- 3.3.7 - Table 1 – Application Layer control field
  @allowed_t_services %{
    group_read: [:t_data_group],
    group_resp: [:t_data_group],
    group_write: [:t_data_group],
    ind_addr_write: [:t_data_broadcast],
    ind_addr_read: [:t_data_broadcast],
    ind_addr_resp: [:t_data_broadcast],
    mem_read: [:t_data_ind, :t_data_con],
    mem_resp: [:t_data_ind, :t_data_con],
    mem_write: [:t_data_ind, :t_data_con],
    user_mem_read: [:t_data_con],
    user_mem_resp: [:t_data_con],
    user_mem_write: [:t_data_con],
    user_manu_info_read: [:t_data_con],
    user_manu_info_resp: [:t_data_con],
    fun_prop_command: [:t_data_ind, :t_data_con],
    fun_prop_state_read: [:t_data_ind, :t_data_con],
    fun_prop_state_resp: [:t_data_ind, :t_data_con],
    device_desc_read: [:t_data_ind, :t_data_con],
    device_desc_resp: [:t_data_ind, :t_data_con],
    restart_basic: [:t_data_ind, :t_data_con],
    restart_master: [:t_data_ind, :t_data_con],
    restart_resp: [:t_data_ind, :t_data_con],
    auth_req: [:t_data_con],
    auth_resp: [:t_data_con],
    key_write: [:t_data_con],
    key_resp: [:t_data_con],
    prop_read: [:t_data_ind, :t_data_con],
    prop_resp: [:t_data_ind, :t_data_con],
    prop_write: [:t_data_ind, :t_data_con],
    prop_desc_read: [:t_data_ind, :t_data_con],
    prop_desc_resp: [:t_data_ind, :t_data_con],
    ind_addr_serial_write: [:t_data_broadcast],
    ind_addr_serial_read: [:t_data_broadcast],
    ind_addr_serial_resp: [:t_data_broadcast]
  }

  def handle({:al, :req, %F{apci: :a_connect} = frame}, _),
    do: [{:tlsm, :req, %F{frame | service: :t_connect}}]

  def handle({:al, :req, %F{apci: :a_discon} = frame}, _),
    do: [{:tlsm, :req, %F{frame | service: :t_discon}}]

  # [XIV]
  def handle({:al, prim, %F{service: :t_connect} = frame}, _),
    do: [{:mgmt, prim, %F{frame | apci: :a_connect}}]

  def handle({:al, prim, %F{service: :t_discon} = frame}, _),
    do: [{:mgmt, prim, %F{frame | apci: :a_discon}}]

  def handle({:al, :req, %F{data: data, apci: apci, service: service} = frame}, _) do
    with :ok <- validate(service in @allowed_t_services[apci], {:forbidden, service, apci}),
         {:ok, data_encoded} <- encode(apci, data) do
      [{:tlsm, :req, %F{frame | data: data_encoded}}]
    else
      {:error, reason} -> [{:logger, :error, reason}]
    end
  end

  def handle({:al, prim, %F{data: data, service: service} = frame}, _) do
    with {next, apci, data_decoded} <- decode(data),
         :ok <- validate(service in @allowed_t_services[apci], {:forbidden, service, apci}) do
      [{next, prim, %{frame | apci: apci, data: data_decoded}}]
    else
      {:error, reason} -> [{:logger, :error, reason}]
    end
  end

  # --------------------------------------

  def get_default_service(apci, mode \\ nil) do
    allowed = Map.get(@allowed_t_services, apci, [nil])

    case mode do
      nil -> allowed |> hd
      mode -> if mode in allowed, do: mode, else: raise("mode not allowed")
    end
  end

  # --------------------------------------

  defp decode(apdu) do
    case apdu do
      <<apci(:group_read)::bits>> ->
        {:go, :group_read, []}

      <<apci(:group_resp)::bits, data::bits>> ->
        {:go, :group_resp, [data]}

      <<apci(:group_write)::bits, data::bits>> ->
        {:go, :group_write, [data]}

      <<apci(:ind_addr_write)::bits, address::16>> ->
        {:io, :ind_addr_write, [address]}

      <<apci(:ind_addr_read)::bits>> ->
        {:io, :ind_addr_read, []}

      <<apci(:ind_addr_resp)::bits>> ->
        {:mgmt, :ind_addr_resp, []}

      <<apci(:mem_read)::bits, number::6, addr::16>> ->
        {:mem, :mem_read, [number, addr]}

      <<apci(:mem_resp)::bits, number::6, addr::16, data::bytes>> ->
        {:mgmt, :mem_resp, [number, addr, data]}

      <<apci(:mem_write)::bits, number::6, addr::16, data::bytes>> ->
        {:mem, :mem_write, [number, addr, data]}

      <<apci(:user_mem_read)::bits, addr_ext::4, number::4, address::16>> ->
        {:mem, :user_mem_read, [addr_ext, number, address]}

      <<apci(:user_mem_resp)::bits, addr_ext::4, number::4, address::16, data::bytes>> ->
        {:mgmt, :user_mem_resp, [addr_ext, number, address, data]}

      <<apci(:user_mem_write)::bits, addr_ext::4, number::4, address::16, data::bytes>> ->
        {:mem, :user_mem_write, [addr_ext, number, address, data]}

      <<apci(:user_manu_info_read)::bits>> ->
        {:todo, :user_manu_info_read, []}

      <<apci(:user_manu_info_resp)::bits, manu_id, manu_specific::16>> ->
        {:todo, :user_manu_info_resp, [manu_id, manu_specific]}

      <<apci(:fun_prop_command)::bits, o_idx, prop_id, data::bytes>> ->
        {:io, :fun_prop_command, [o_idx, prop_id, data]}

      <<apci(:fun_prop_state_read)::bits, o_idx, prop_id, data::bytes>> ->
        {:io, :fun_prop_state_read, [o_idx, prop_id, data]}

      <<apci(:fun_prop_state_resp)::bits, o_idx, prop_id, return_code, data::bytes>> ->
        {:todo, :fun_prop_state_resp, [o_idx, prop_id, return_code, data]}

      <<apci(:device_desc_read)::bits, desc_type::6>> ->
        {:io, :device_desc_read, [desc_type]}

      <<apci(:device_desc_resp)::bits, desc_type::6, desc::bytes>> ->
        {:mgmt, :device_desc_resp, [desc_type, desc]}

      <<apci(:restart_basic)::bits>> ->
        {:restart, :restart_basic, []}

      # <<apci(:restart_master)::bits, erase_code, channel_number>> ->
      #   {:restart, :restart_master, [erase_code, channel_number]}

      # <<apci(:restart_resp)::bits, error_code, process_time::16>> ->
      #   {:mgmt, :restart_resp, [error_code, process_time]}

      <<apci(:auth_req)::bits, 0, key::32>> ->
        {:auth, :auth_req, [key]}

      <<apci(:auth_resp)::bits, level>> ->
        {:mgmt, :auth_resp, [level]}

      <<apci(:key_write)::bits, level, key::32>> ->
        {:auth, :key_write, [level, key]}

      <<apci(:key_resp)::bits, level>> ->
        {:mgmt, :key_resp, [level]}

      <<apci(:prop_read)::bits, o_idx, pid, elems::4, start::12>> ->
        {:io, :prop_read, [o_idx, pid, elems, start]}

      <<apci(:prop_resp)::bits, o_idx, pid, elems::4, start::12, data::bytes>> ->
        {:mgmt, :prop_resp, [o_idx, pid, elems, start, data]}

      <<apci(:prop_write)::bits, o_idx, pid, elems::4, start::12, data::bytes>> ->
        {:io, :prop_write, [o_idx, pid, elems, start, data]}

      <<apci(:prop_desc_read)::bits, o_idx, pid, p_idx>> ->
        {:io, :prop_desc_read, [o_idx, pid, p_idx]}

      <<apci(:prop_desc_resp)::bits, o_idx, pid, p_idx, write::1, 0::1, type::6, 0::4, max::12,
        r_lvl::4, w_lvl::4>> ->
        {:mgmt, :prop_desc_resp, [o_idx, pid, p_idx, write, type, max, r_lvl, w_lvl]}

      <<apci(:ind_addr_serial_write)::bits, serial::48, ind_addr::16, _reserved::32>> ->
        {:io, :ind_addr_serial_write, [serial, ind_addr]}

      <<apci(:ind_addr_serial_read)::bits, serial::48>> ->
        {:io, :ind_addr_serial_read, [serial]}

      <<apci(:ind_addr_serial_resp)::bits, serial::48, domain_addr::16, _reserved::16>> ->
        {:mgmt, :ind_addr_serial_resp, [serial, domain_addr]}

      _ ->
        {:error, :malformed_apdu}
    end
  end

  defp encode(apci, data) do
    encoded =
      case apci do
        :group_read -> a_group_read_pdu()
        :group_resp -> a_group_resp_pdu(data)
        :group_write -> a_group_write_pdu(data)
        :ind_addr_write -> a_ind_addr_write_pdu(data)
        :ind_addr_read -> a_ind_addr_read_pdu()
        :ind_addr_resp -> a_ind_addr_resp_pdu()
        :mem_read -> a_mem_read_pdu(data)
        :mem_resp -> a_mem_resp_pdu(data)
        :mem_write -> a_mem_write_pdu(data)
        :user_mem_read -> a_user_mem_read_pdu(data)
        :user_mem_resp -> a_user_mem_resp_pdu(data)
        :user_mem_write -> a_user_mem_write_pdu(data)
        :user_manu_info_read -> a_user_manu_info_read_pdu()
        :user_manu_info_resp -> a_user_manu_info_resp_pdu(data)
        # TODO
        :fun_prop_command -> <<>>
        :fun_prop_state_read -> <<>>
        :fun_prop_state_resp -> <<>>
        :device_desc_read -> a_device_desc_read_pdu(data)
        :device_desc_resp -> a_device_desc_resp_pdu(data)
        :restart_basic -> a_restart_basic_pdu()
        # :restart_master -> a_restart_master_pdu(data)
        # :restart_resp -> a_restart_resp_pdu(data)
        :auth_req -> a_auth_req_pdu(data)
        :auth_resp -> a_auth_resp_pdu(data)
        :key_write -> a_key_write_pdu(data)
        :key_resp -> a_key_resp_pdu(data)
        :prop_read -> a_prop_read_pdu(data)
        :prop_resp -> a_prop_resp_pdu(data)
        :prop_write -> a_prop_write_pdu(data)
        :prop_desc_read -> a_prop_desc_read_pdu(data)
        :prop_desc_resp -> a_prop_desc_resp_pdu(data)
        :ind_addr_serial_write -> a_ind_addr_serial_write_pdu(data)
        :ind_addr_serial_read -> a_ind_addr_serial_read_pdu(data)
        :ind_addr_serial_resp -> a_ind_addr_serial_resp_pdu(data)
        _ -> :error
      end

    case encoded do
      :error -> {:error, {:unknown_apci, apci}}
      _ -> {:ok, encoded}
    end
  end

  def a_device_desc_read_pdu([descriptor_type]),
    do: <<apci(:device_desc_read)::bits, descriptor_type::6>>

  def a_prop_desc_resp_pdu([o_idx, pid, p_idx, write, pdt, max, r_lvl, w_lvl]),
    do:
      <<apci(:prop_desc_resp)::bits, o_idx, pid, p_idx, write::1, 0::1, pdt::6, 0::4, max::12,
        r_lvl::4, w_lvl::4>>

  def a_prop_resp_pdu([o_idx, pid, elems, start, data]),
    do: <<apci(:prop_resp)::bits, o_idx, pid, elems::4, start::12, data::bytes>>

  def a_mem_resp_pdu([count, address, data]),
    do: <<apci(:mem_resp)::bits, count::6, address::16, data::bytes>>

  def a_ind_addr_resp_pdu(),
    do: <<apci(:ind_addr_resp)::bits>>

  # NOTE: the IA is returned as src-address
  def a_ind_addr_serial_resp_pdu([serial, domain_address]),
    do: <<apci(:ind_addr_serial_resp)::bits, serial::48, domain_address::16, 0::16>>

  def a_auth_resp_pdu([level]),
    do: <<apci(:auth_resp)::bits, level>>

  def a_key_resp_pdu([level]),
    do: <<apci(:key_resp)::bits, level>>

  def a_auth_req_pdu([key]),
    do: <<apci(:auth_req)::bits, 0, key::32>>

  def a_device_desc_resp_pdu([descriptor_type, descriptor]),
    do: <<apci(:device_desc_resp)::bits, descriptor_type::6, descriptor::bytes>>

  def a_fun_prop_command_pdu([o_idx, prop_id, data]),
    do: <<apci(:fun_prop_command)::bits, o_idx, prop_id, data::bytes>>

  def a_fun_prop_state_read_pdu([o_idx, prop_id, data]),
    do: <<apci(:fun_prop_state_read)::bits, o_idx, prop_id, data::bytes>>

  def a_fun_prop_state_resp_pdu([o_idx, prop_id, return_code, data]),
    do: <<apci(:fun_prop_state_resp)::bits, o_idx, prop_id, return_code, data::bytes>>

  def a_group_read_pdu(),
    do: <<apci(:group_read)::bits>>

  # TODO: different sizes of resp-PDU have to be handled
  def a_group_resp_pdu([data]),
    do: <<apci(:group_resp)::bits, data::bits>>

  # TODO: different sizes of write-PDU have to be handled
  def a_group_write_pdu([data]),
    do: <<apci(:group_write)::bits, data::bits>>

  def a_ind_addr_read_pdu(),
    do: <<apci(:ind_addr_read)::bits>>

  def a_ind_addr_serial_read_pdu([serial]),
    do: <<apci(:ind_addr_serial_read)::bits, serial::48>>

  def a_ind_addr_serial_write_pdu([serial, ind_addr]),
    do: <<apci(:ind_addr_serial_write)::bits, serial::48, ind_addr::16, 0::32>>

  def a_ind_addr_write_pdu([address]),
    do: <<apci(:ind_addr_write)::bits, address::16>>

  def a_key_write_pdu([level, key]),
    do: <<apci(:key_write)::bits, level, key::32>>

  def a_mem_read_pdu([number, addr]),
    do: <<apci(:mem_read)::bits, number::6, addr::16>>

  def a_mem_write_pdu([number, addr, data]),
    do: <<apci(:mem_write)::bits, number::6, addr::16, data::bytes>>

  def a_prop_desc_read_pdu([o_idx, pid, p_idx]),
    do: <<apci(:prop_desc_read)::bits, o_idx, pid, p_idx>>

  def a_prop_read_pdu([o_idx, pid, elems, start]),
    do: <<apci(:prop_read)::bits, o_idx, pid, elems::4, start::12>>

  def a_prop_write_pdu([o_idx, pid, elems, start, data]),
    do: <<apci(:prop_write)::bits, o_idx, pid, elems::4, start::12, data::bytes>>

  def a_restart_basic_pdu(),
    do: <<apci(:restart_basic)::bits>>

  # def a_restart_master_pdu([erase_code, channel_number]),
  #   do: <<apci(:restart_basic)::bits, erase_code, channel_number>>

  # def a_restart_resp_pdu([error_code, process_time]),
  #   do: <<apci(:restart_resp)::bits, error_code, process_time::16>>

  def a_user_manu_info_read_pdu(),
    do: <<apci(:user_manu_info_read)::bits>>

  def a_user_manu_info_resp_pdu([manu_id, manu_specific]),
    do: <<apci(:user_manu_info_resp)::bits, manu_id, manu_specific::16>>

  def a_user_mem_read_pdu([addr_ext, number, address]),
    do: <<apci(:user_mem_read)::bits, addr_ext::4, number::4, address::16>>

  def a_user_mem_resp_pdu([addr_ext, number, address, data]),
    do: <<apci(:user_mem_resp)::bits, addr_ext::4, number::4, address::16, data::bytes>>

  def a_user_mem_write_pdu([addr_ext, number, address, data]),
    do: <<apci(:user_mem_write)::bits, addr_ext::4, number::4, address::16, data::bytes>>
end
