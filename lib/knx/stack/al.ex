defmodule Knx.Stack.Al do
  alias Knx.Frame, as: F
  require PureLogger

  import Knx.Toolbox

  # --- 3.3.7 - Table 1 – Application Layer control field
  @allowed_t_services %{
    group_read: [:t_data_group],
    group_resp: [:t_data_group],
    group_write: [:t_data_group],
    ind_addr_write: [:t_data_broadcast],
    ind_addr_read: [:t_data_broadcast],
    ind_addr_resp: [:t_data_broadcast],
    # adc_read: [:t_data_con],
    # adc_resp: [:t_data_con],
    # sys_nw_param_read: [:t_data_sys_broadcast],
    # sys_nw_param_resp: [:t_data_sys_broadcast],
    # sys_nw_param_write: [:t_data_sys_broadcast],
    mem_read: [:t_data_ind, :t_data_con],
    mem_resp: [:t_data_ind, :t_data_con],
    mem_write: [:t_data_ind, :t_data_con],
    user_mem_read: [:t_data_con],
    user_mem_resp: [:t_data_con],
    user_mem_write: [:t_data_con],
    # user_mem_bit_write: [:t_data_con],
    user_manu_info_read: [:t_data_con],
    user_manu_info_resp: [:t_data_con],
    fun_prop_command: [:t_data_ind, :t_data_con],
    fun_prop_state_read: [:t_data_ind, :t_data_con],
    fun_prop_state_resp: [:t_data_ind, :t_data_con],
    device_desc_read: [:t_data_ind, :t_data_con],
    device_desc_resp: [:t_data_ind, :t_data_con],
    restart_basic: [:t_data_ind, :t_data_con],
    # restart_master: [:t_data_ind, :t_data_con],
    # restart_resp: [:t_data_ind, :t_data_con],
    # mem_bit_write: [:t_data_con],
    auth_req: [:t_data_con],
    auth_resp: [:t_data_con],
    key_write: [:t_data_con],
    key_resp: [:t_data_con],
    prop_read: [:t_data_ind, :t_data_con],
    prop_resp: [:t_data_ind, :t_data_con],
    prop_write: [:t_data_ind, :t_data_con],
    prop_desc_read: [:t_data_ind, :t_data_con],
    prop_desc_resp: [:t_data_ind, :t_data_con],
    # nw_param_read: [:t_data_ind],
    # nw_param_resp: [:t_data_broadcast, :t_data_ind],
    # nw_param_write: [:t_data_ind],
    ind_addr_serial_write: [:t_data_broadcast],
    ind_addr_serial_read: [:t_data_broadcast],
    ind_addr_serial_resp: [:t_data_broadcast]
  }

  @group_read 0b0000_000000
  @group_resp 0b0001
  @group_write 0b0010

  @ind_addr_write 0b0011_000000
  @ind_addr_read 0b0100_000000
  @ind_addr_resp 0b0101_000000

  # @adc_read 0b0110
  # @adc_resp 0b0111

  # @sys_nw_param_read 0b0111_001000
  # @sys_nw_param_resp 0b0111_001001
  # @sys_nw_param_write 0b0111_001010

  @mem_read 0b1000
  @mem_resp 0b1001
  @mem_write 0b1010

  @user_mem_read 0b1011_000000
  @user_mem_resp 0b1011_000001
  @user_mem_write 0b1011_000010

  # not for future use
  # @user_mem_bit_write 0b1011_000100

  @user_manu_info_read 0b1011_000101
  @user_manu_info_resp 0b1011_000110

  @fun_prop_command 0b1011_000111
  @fun_prop_state_read 0b1011_001000
  @fun_prop_state_resp 0b1011_001001

  # 0b1011_001010 - 0b1011_110111 -- reserved USERMSG
  # 0b1011_111000 - 0b1011_111110 -- manufacturer specific area for USERMSG

  @device_desc_read 0b1100
  @device_desc_resp 0b1101

  @restart_basic 0b1110_000000
  # @restart_master 0b1110_000001
  # @restart_resp 0b1110_100001

  # coupler specific services - all not for future use
  # ...

  # not for future use
  # @mem_bit_write 0b1111_010000

  @auth_req 0b1111_010001
  @auth_resp 0b1111_010010
  @key_write 0b1111_010011
  @key_resp 0b1111_010100

  @prop_read 0b1111_010101
  @prop_resp 0b1111_010110
  @prop_write 0b1111_010111
  @prop_desc_read 0b1111_011000
  @prop_desc_resp 0b1111_011001

  # @nw_param_read 0b1111_011010
  # @nw_param_resp 0b1111_011011

  @ind_addr_serial_read 0b1111_011100
  @ind_addr_serial_resp 0b1111_011101
  @ind_addr_serial_write 0b1111_011110

  # open media specific services

  # @nw_param_write 0b1111_100100

  # --- /end Table 1

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

  def get_default_service(apci, mode) do
    allowed = Map.get(@allowed_t_services, apci, [nil])

    case mode do
      nil -> allowed |> hd
      mode -> if mode in allowed, do: mode, else: raise("mode not allowed")
    end
  end

  # --------------------------------------

  defp decode(apdu) do
    case apdu do
      <<@group_read::10>> ->
        {:go, :group_read, []}

      <<@group_resp::4, data::bits>> ->
        {:go, :group_resp, [data]}

      <<@group_write::4, data::bits>> ->
        {:go, :group_write, [data]}

      <<@ind_addr_write::10, address::16>> ->
        {:io, :ind_addr_write, [address]}

      <<@ind_addr_read::10>> ->
        {:io, :ind_addr_read, []}

      <<@ind_addr_resp::10>> ->
        {:mgmt, :ind_addr_resp, []}

      # <<@adc_read::4, channel::6, read_count>> ->
      #   {:adc, :adc_read, [channel, read_count]}

      # <<@adc_resp::4, channel::6, read_count, sum::16>> ->
      #   {:mgmt, :adc_resp, [channel, read_count, sum]}

      # <<@sys_nw_param_read::10, obj_type::16, pid::12, 0::4, operand>> ->
      #   {:___, :sys_nw_param_read, [obj_type, pid, operand]}

      # <<@sys_nw_param_resp::10, obj_type::16, pid::12, 0::4, operand, result::bytes>> ->
      #   {:___, :sys_nw_param_resp, [obj_type, pid, operand, result]}

      # <<@sys_nw_param_write::10, obj_type::16, pid::12, 0::4, value::bytes>> ->
      #   {:___, :sys_nw_param_write, [obj_type, pid, value]}

      <<@mem_read::4, number::6, addr::16>> ->
        {:mem, :mem_read, [number, addr]}

      <<@mem_resp::4, number::6, addr::16, data::bytes>> ->
        {:mgmt, :mem_resp, [number, addr, data]}

      <<@mem_write::4, number::6, addr::16, data::bytes>> ->
        {:mem, :mem_write, [number, addr, data]}

      <<@user_mem_read::10, addr_ext::4, number::4, address::16>> ->
        {:mem, :user_mem_read, [addr_ext, number, address]}

      <<@user_mem_resp::10, addr_ext::4, number::4, address::16, data::bytes>> ->
        {:mgmt, :user_mem_resp, [addr_ext, number, address, data]}

      <<@user_mem_write::10, addr_ext::4, number::4, address::16, data::bytes>> ->
        {:mem, :user_mem_write, [addr_ext, number, address, data]}

      # <<@user_mem_bit_write::10, number, address::16, data::bytes>> ->
      #   {:mem, :user_mem_bit_write, [number, address, data]}

      <<@user_manu_info_read::10>> ->
        {:todo, :user_manu_info_read, []}

      <<@user_manu_info_resp::10, manu_id, manu_specific::16>> ->
        {:todo, :user_manu_info_resp, [manu_id, manu_specific]}

      <<@fun_prop_command::10, o_idx, prop_id, data::bytes>> ->
        {:io, :fun_prop_command, [o_idx, prop_id, data]}

      <<@fun_prop_state_read::10, o_idx, prop_id, data::bytes>> ->
        {:io, :fun_prop_state_read, [o_idx, prop_id, data]}

      <<@fun_prop_state_resp::10, o_idx, prop_id, return_code, data::bytes>> ->
        {:todo, :fun_prop_state_resp, [o_idx, prop_id, return_code, data]}

      <<@device_desc_read::4, desc_type::6>> ->
        {:io, :device_desc_read, [desc_type]}

      <<@device_desc_resp::4, desc_type::6, desc::bytes>> ->
        {:mgmt, :device_desc_resp, [desc_type, desc]}

      <<@restart_basic::10>> ->
        {:restart, :restart_basic, []}

      # <<@restart_master::10, erase_code, channel_number>> ->
      #   {:restart, :restart_master, [erase_code, channel_number]}

      # <<@restart_resp::10, error_code, process_time::16>> ->
      #   {:mgmt, :restart_resp, [error_code, process_time]}

      # <<@mem_bit_write::10, number, address::16, data::bytes>> ->
      #   {:mem, :mem_bit_write, [number, address, data]}

      <<@auth_req::10, 0, key::32>> ->
        {:auth, :auth_req, [key]}

      <<@auth_resp::10, level>> ->
        {:mgmt, :auth_resp, [level]}

      <<@key_write::10, level, key::32>> ->
        {:auth, :key_write, [level, key]}

      <<@key_resp::10, level>> ->
        {:mgmt, :key_resp, [level]}

      <<@prop_read::10, o_idx, pid, elems::4, start::12>> ->
        {:io, :prop_read, [o_idx, pid, elems, start]}

      <<@prop_resp::10, o_idx, pid, elems::4, start::12, data::bytes>> ->
        {:mgmt, :prop_resp, [o_idx, pid, elems, start, data]}

      <<@prop_write::10, o_idx, pid, elems::4, start::12, data::bytes>> ->
        {:io, :prop_write, [o_idx, pid, elems, start, data]}

      <<@prop_desc_read::10, o_idx, pid, p_idx>> ->
        {:io, :prop_desc_read, [o_idx, pid, p_idx]}

      <<@prop_desc_resp::10, o_idx, pid, p_idx, write::1, 0::1, type::6, 0::4, max::12, r_lvl::4,
        w_lvl::4>> ->
        {:mgmt, :prop_desc_resp, [o_idx, pid, p_idx, write, type, max, r_lvl, w_lvl]}

      # <<@nw_param_read::10, obj_type::16, pid, test_info::bytes>> ->
      #   {:___, :nw_param_read, [obj_type, pid, test_info]}

      # <<@nw_param_resp::10, obj_type::16, pid, test_info_and_result::bytes>> ->
      #   {:___, :nw_param_resp, [obj_type, pid, test_info_and_result]}

      # <<@nw_param_write::10, obj_type::16, pid, value::bytes>> ->
      #   {:___, :nw_param_write, [obj_type, pid, value]}

      <<@ind_addr_serial_write::10, serial::48, ind_addr::16, _reserved::32>> ->
        {:io, :ind_addr_serial_write, [serial, ind_addr]}

      <<@ind_addr_serial_read::10, serial::48>> ->
        {:io, :ind_addr_serial_read, [serial]}

      <<@ind_addr_serial_resp::10, serial::48, domain_addr::16, _reserved::16>> ->
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
        # :adc_read -> a_adc_read_pdu(data)
        # :adc_resp -> a_adc_resp_pdu(data)
        # :sys_nw_param_read -> a_sys_nw_param_read_pdu(data)
        # :sys_nw_param_resp -> a_sys_nw_param_resp_pdu(data)
        # :sys_nw_param_write -> a_sys_nw_param_write_pdu(data)
        :mem_read -> a_mem_read_pdu(data)
        :mem_resp -> a_mem_resp_pdu(data)
        :mem_write -> a_mem_write_pdu(data)
        :user_mem_read -> a_user_mem_read_pdu(data)
        :user_mem_resp -> a_user_mem_resp_pdu(data)
        :user_mem_write -> a_user_mem_write_pdu(data)
        # :user_mem_bit_write -> a_user_mem_bit_write_pdu(data)
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
        # :mem_bit_write -> a_mem_bit_write_pdu(data)
        :auth_req -> a_auth_req_pdu(data)
        :auth_resp -> a_auth_resp_pdu(data)
        :key_write -> a_key_write_pdu(data)
        :key_resp -> a_key_resp_pdu(data)
        :prop_read -> a_prop_read_pdu(data)
        :prop_resp -> a_prop_resp_pdu(data)
        :prop_write -> a_prop_write_pdu(data)
        :prop_desc_read -> a_prop_desc_read_pdu(data)
        :prop_desc_resp -> a_prop_desc_resp_pdu(data)
        # :nw_param_read -> a_nw_param_read_pdu(data)
        # :nw_param_resp -> a_nw_param_resp_pdu(data)
        # :nw_param_write -> a_nw_param_write_pdu(data)
        :ind_addr_serial_write -> a_ind_addr_serial_write_pdu(data)
        :ind_addr_serial_read -> a_ind_addr_serial_read_pdu(data)
        :ind_addr_serial_resp -> a_ind_addr_serial_resp_pdu(data)
        _ -> :error
      end

    case encoded do
      :error -> {:error, :unknown_apci, apci}
      _ -> {:ok, encoded}
    end
  end

  def a_device_desc_read_pdu([descriptor_type]),
    do: <<@device_desc_read::4, descriptor_type::6>>

  def a_prop_desc_resp_pdu([o_idx, pid, p_idx, write, pdt, max, r_lvl, w_lvl]),
    do:
      <<@prop_desc_resp::10, o_idx, pid, p_idx, write::1, 0::1, pdt::6, 0::4, max::12, r_lvl::4,
        w_lvl::4>>

  def a_prop_resp_pdu([o_idx, pid, elems, start, data]),
    do: <<@prop_resp::10, o_idx, pid, elems::4, start::12, data::bytes>>

  def a_mem_resp_pdu([count, address, data]),
    do: <<@mem_resp::4, count::6, address::16, data::bytes>>

  def a_ind_addr_resp_pdu(),
    do: <<@ind_addr_resp::10>>

  # NOTE: the IA is returned as src-address
  def a_ind_addr_serial_resp_pdu([serial, domain_address]),
    do: <<@ind_addr_serial_resp::10, serial::48, domain_address::16, 0::16>>

  def a_auth_resp_pdu([level]),
    do: <<@auth_resp::10, level>>

  def a_key_resp_pdu([level]),
    do: <<@key_resp::10, level>>

  # def a_adc_read_pdu([channel, read_count]),
  #   do: <<@adc_read::4, channel::6, read_count>>

  # def a_adc_resp_pdu([channel, read_count, sum]),
  #   do: <<@adc_resp::4, channel::6, read_count, sum::16>>

  def a_auth_req_pdu([key]),
    do: <<@auth_req::10, 0, key::32>>

  def a_device_desc_resp_pdu([descriptor_type, descriptor]),
    do: <<@device_desc_resp::4, descriptor_type::6, descriptor::bytes>>

  def a_fun_prop_command_pdu([o_idx, prop_id, data]),
    do: <<@fun_prop_command::10, o_idx, prop_id, data::bytes>>

  def a_fun_prop_state_read_pdu([o_idx, prop_id, data]),
    do: <<@fun_prop_state_read::10, o_idx, prop_id, data::bytes>>

  def a_fun_prop_state_resp_pdu([o_idx, prop_id, return_code, data]),
    do: <<@fun_prop_state_resp::10, o_idx, prop_id, return_code, data::bytes>>

  def a_group_read_pdu(),
    do: <<@group_read::10>>

  # TODO: different sizes of resp-PDU have to be handled
  def a_group_resp_pdu([data]),
    do: <<@group_resp::4, data::bits>>

  # TODO: different sizes of write-PDU have to be handled
  def a_group_write_pdu([data]),
    do: <<@group_write::4, data::bits>>

  def a_ind_addr_read_pdu(),
    do: <<@ind_addr_read::10>>

  def a_ind_addr_serial_read_pdu([serial]),
    do: <<@ind_addr_serial_read::10, serial::48>>

  def a_ind_addr_serial_write_pdu([serial, ind_addr]),
    do: <<@ind_addr_serial_write::10, serial::48, ind_addr::16, 0::32>>

  def a_ind_addr_write_pdu([address]),
    do: <<@ind_addr_write::10, address::16>>

  def a_key_write_pdu([level, key]),
    do: <<@key_write::10, level, key::32>>

  # def a_mem_bit_write_pdu([number, address, data]),
  #   do: <<@mem_bit_write::10, number, address::16, data::bytes>>

  def a_mem_read_pdu([number, addr]),
    do: <<@mem_read::4, number::6, addr::16>>

  def a_mem_write_pdu([number, addr, data]),
    do: <<@mem_write::4, number::6, addr::16, data::bytes>>

  # def a_nw_param_read_pdu([obj_type, pid, test_info]),
  #   do: <<@nw_param_read::10, obj_type::16, pid, test_info::bytes>>

  # def a_nw_param_resp_pdu([obj_type, pid, test_info_and_result]),
  #   do: <<@nw_param_resp::10, obj_type::16, pid, test_info_and_result::bytes>>

  # def a_nw_param_write_pdu([obj_type, pid, value]),
  #   do: <<@nw_param_write::10, obj_type::16, pid, value::bytes>>

  def a_prop_desc_read_pdu([o_idx, pid, p_idx]),
    do: <<@prop_desc_read::10, o_idx, pid, p_idx>>

  def a_prop_read_pdu([o_idx, pid, elems, start]),
    do: <<@prop_read::10, o_idx, pid, elems::4, start::12>>

  def a_prop_write_pdu([o_idx, pid, elems, start, data]),
    do: <<@prop_write::10, o_idx, pid, elems::4, start::12, data::bytes>>

  def a_restart_basic_pdu(),
    do: <<@restart_basic::10>>

  # def a_restart_master_pdu([erase_code, channel_number]),
  #   do: <<@restart_basic::10, erase_code, channel_number>>

  # def a_restart_resp_pdu([error_code, process_time]),
  #   do: <<@restart_resp::10, error_code, process_time::16>>

  # def a_sys_nw_param_read_pdu([obj_type, pid, operand]),
  #   do: <<@sys_nw_param_read::10, obj_type::16, pid::12, 0::4, operand>>

  # def a_sys_nw_param_resp_pdu([obj_type, pid, operand, result]),
  #   do: <<@sys_nw_param_resp::10, obj_type::16, pid::12, 0::4, operand, result::bytes>>

  # def a_sys_nw_param_write_pdu([obj_type, pid, value]),
  #   do: <<@sys_nw_param_write::10, obj_type::16, pid::12, 0::4, value::bytes>>

  def a_user_manu_info_read_pdu(),
    do: <<@user_manu_info_read::10>>

  def a_user_manu_info_resp_pdu([manu_id, manu_specific]),
    do: <<@user_manu_info_resp::10, manu_id, manu_specific::16>>

  # def a_user_mem_bit_write_pdu([number, address, data]),
  #   do: <<@user_mem_bit_write::10, number, address::16, data::bytes>>

  def a_user_mem_read_pdu([addr_ext, number, address]),
    do: <<@user_mem_read::10, addr_ext::4, number::4, address::16>>

  def a_user_mem_resp_pdu([addr_ext, number, address, data]),
    do: <<@user_mem_resp::10, addr_ext::4, number::4, address::16, data::bytes>>

  def a_user_mem_write_pdu([addr_ext, number, address, data]),
    do: <<@user_mem_write::10, addr_ext::4, number::4, address::16, data::bytes>>
end
