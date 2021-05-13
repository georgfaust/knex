# “Commons Clause” License Condition v1.0

# The Software is provided to you by the Licensor under the License, as defined below, subject to the following condition.
# Without limiting other conditions in the License, the grant of rights under the License will not include, and the License does not grant to you, the right to Sell the Software.
# For purposes of the foregoing, “Sell” means practicing any or all of the rights granted to you under the License to provide to third parties, for a fee or other consideration (including without limitation fees for hosting or consulting/ support services related to the Software), a product or service whose value derives, entirely or substantially, from the functionality of the Software. Any license notice or attribution required by the License must also include this Commons Clause License Condition notice.

# Software: KNeX - management_procedures.ex
# License: MIT
# Licensor: Sebastian Fey

defmodule Knx.ManagementProcedures do
  alias Knx.Api
  alias Knx.Ail.Property, as: P
  import Knx.Toolbox
  require Knx.Defs
  import Knx.Defs

  # TODO duplication
  @device_object 0

  @nm_ind_addr_read_timeout 300
  @nm_ind_addr_write 100

  def nm_ind_addr_read(pid) do
    case Api.ind_addr_read(pid, @nm_ind_addr_read_timeout) do
      {:api_multi_result, _, result} -> Enum.map(result, &Map.get(&1, :src))
      {:error, _} -> []
    end
  end

  def nm_ind_addr_write(pid, ia_new) do
    with {:not_connected, _} <- connect(pid, ia_new),
         {:in_prog_mode, [ia]} <- wait_for_prog_mode(pid, @nm_ind_addr_write),
         :ok <- prog_if_differs(pid, ia, ia_new),
         :timer.sleep(5),
         {_, %{apci: :a_connect}} <- Api.connect(pid, ia_new),
         {_, %{apci: :device_desc_resp}} <- Api.device_desc_read(pid, ia_new),
         _ <- Api.restart(pid, ia, :basic),
         _ <- Api.discon(pid) do
      :ok
    else
      {:connected, _} -> {:error, :occupied}
      {:error, :ia_equal} -> {:error, :ia_equal}
      {:in_prog_mode, ia_addrs} -> {:error, :more_than_one_in_prog_mode, ia_addrs}
      error -> {:error, :unexpected, error}
    end
  end

  def nm_ind_addr_serial_read(pid, sn) do
    case Api.ind_addr_serial_read(pid, sn) do
      {_, %{apci: :ind_addr_serial_resp, data: [sn_recv, doa], src: src}} when sn_recv == sn ->
        {:ok, src, doa}

      error ->
        error
    end
  end

  # def nm_ind_addr_serial_write(pid) do
  #   # TODO - das fehlt in procedure
  #   # The procedure shall ensure that the assigned Individual Address is unique. The procedure shall check if
  #   # the programming has been successful.
  # end

  # TODO unklar, siehe defp
  # def nm_router_scan(pid) do
  #   found = scan_router(pid, 0, [])
  #   dmp_delay(6000)
  #   found
  # end

  # TODO unklar, siehe defp
  # def nm_subnetworkdevices_scan(pid, sna) do
  #   sna = sna * 0x100
  #   found = scan_device(pid, sna, 0, [])
  #   dmp_delay(6000)
  #   found
  # end

  def nm_ind_addr_reset(pid) do
    with {_, %{apci: :ind_addr_write}} <- Api.ind_addr_write(pid, 0xFFFF),
      :timer.sleep(2),
         {_, %{apci: :a_connect}} <- Api.connect(pid, 0xFFFF),
         {_, %{apci: :restart_basic}} <- Api.restart(pid, 0xFFFF, :basic),
         _ <- Api.discon(pid) do
      wait_until(
        fn -> Api.ind_addr_read(pid, 100) end,
        {:api_multi_result, :ind_addr_resp, []}
      )
    end
  end

  # TODO:test/fix connect first
  def nm_ind_addr_check(pid, ia) do
    case connect(pid, ia) do
      {:connected, _msg} -> :yes
      _ -> :no
    end
  end

  # TODO 7000 > 5000 (genserver call timeout) -> habe auf 700 reduziert.
  def nm_serial_default_ia_scan(pid) do
    {:api_multi_result, :prop_resp, response} =
      Api.prop_read(pid, 0xFFFF, @device_object, prop_id(:serial), :cl, %{
        multi: true,
        timeout_ms: 700
      })

    Enum.map(response, &extract_prop_resp_data(&1))
  end

  # custom nmp
  def nm_serial_ia_scan(pid, ia) do
    {:api_multi_result, :prop_resp, response} =
      Api.prop_read(pid, ia, @device_object, prop_id(:serial), :cl, %{
        multi: true,
        timeout_ms: 700
      })

    Enum.map(response, &extract_prop_resp_data(&1))
  end

  # TODO - DM_Connect_RCo already returns the value of the Device Descriptor Type 0 of the Management Server. This result is
  #        part of the return of this procedure NM_Identify_RCo2.

  # def dm_connect(pid, ia, 0), do: dmp_connect_rco(pid, ia)
  # def dm_connect(pid, ia, 1), do: dmp_connect_rcl(pid, ia)

  # TODO:test/fix connect first
  def dmp_connect_rco(pid, ia) do
    connect(pid, ia)
  end

  # def dmp_connect_rcl(pid) do
  # end

  def dm_disconnect(_pid) do
    # TODO gibt es immer flags als param, bei manchen params sind die einfach leer, wie hier:
    # (oder ist das ein typo, procedure-signatures sind generell nicht sauber definiert)
    # flags
    #   All other bits are reserved. These shall be set to 0. This shall be
    #   tested by the Management Client.
  end

  # TODO:test/fix connect first
  def dmp_disconnect_rco(pid) do
    Api.discon(pid)
  end

  # TODO dm_identify_rco for desc==300h
  # def dm_identify(pid, ia), do: dm_identify_rco2(pid, ia)

  # TODO desc is one of the return value, but the standard states:
  #   DM_Connect_RCo already returns the value of the Device Descriptor Type 0 of the Management Server. This result is
  #   part of the return of this procedure NM_Identify_RCo2.
  # so it was executed BEFORE !!??

  # TODO:test/fix connect first
  def dm_identify_rco2(pid, ia) do
    with {:ok, desc} <- dmp_connect_rco(pid, ia),
         {:ok, :prop_resp, manu_id} <-
           Api.prop_read_x(pid, ia, @device_object, prop_id(:manu_id)),
         {:ok, :prop_resp, hardware_type} <-
           Api.prop_read_x(pid, ia, @device_object, prop_id(:hw_type)) do
      {:ok, desc, manu_id, hardware_type}
    end
  end

  # Whether or not a Management Server supports authorisation can directly be retrieved from the Device
  # Descriptor Type 0 (mask version). In [08] it is specified for which Profiles authorisation is mandatory.
  # --> Profiles 4.2 - Opt: 3 Mand: 7 - ist also nicht klar

  # TODO mit ETS ausprobieren was passiert beim locken

  # what should be returned? assuming: key, level, assuming level 3 for FFFFFFFF

  # TODO:test/low prio
  def dmp_authorize_rco(_pid, 0xFFFF_FFFF = key), do: {:ok, key, 3}

  # TODO:test/low prio
  def dmp_authorize_rco(pid, ia, key) do
    case Api.call_(pid, %{apci: :auth_req, dest: ia, data: [key]}) do
      {_, %{apci: :auth_resp, data: [level]}} -> {:ok, key, level}
      error -> {:error, error}
    end
  end

  # TODO:test/low prio
  def dm_setkey_rco(pid, ia, key, level) do
    case Api.call_(pid, %{apci: :key_write, dest: ia, data: [level, key]}) do
      {_, %{apci: :key_resp, data: [resp_level]}} when resp_level == level -> {:ok, key, level}
      {_, %{apci: :key_resp}} -> {:error, :granted_unexpected_level}
      error -> {:error, error}
    end
  end

  # def dm_restart_rcl(pid) do
  # end

  # def dm_restart_rco(pid) do
  # end

  def dmp_delay(delay_time_ms) do
    :timer.sleep(delay_time_ms)
  end

  # TODO only for Programming Mode – Realisation Type 2 --> standard version 2.1.4 ??
  # def dmp_progmodeswitch_rco(pid) do
  # end

  # NOTE: this DMP does not follow the signature in the standard.
  # TODO if verify is enabled in the server this procedure will fail!
  #     (unexpected mem_resp)
  # TODO how does the procedure know max-apu-len? (I invented the max_len param)
  # TODO If the Management Server supports L_Data_Extended frames, then the maximal size shall be
  #     adapted in function of the capabilities of the Management Server and possible Couplers and
  #     Routers in the communication path to the Management Client. This is specified in [04].
  # TODO The delay time (between writes) depends on the Management Server and on the
  #     amount of written octets (see [08]). --> I invented param delay
  def dmp_memwrite_rco(pid, ia, verify, ref, data, delay, max_len \\ 12) do
    chunks = chunk_binary(data, max_len, [])
    mem_write_chunks(pid, ia, verify, ref, delay, chunks)
  end

  # TODO "if Verify Mode is not active" -- how do we know that?
  def dmp_memwrite_rcov(pid, ia, ref, data, max_len \\ 12) do
    chunks = chunk_binary(data, max_len, [])

    with :ok <- enable_verify(pid, ia),
         :ok <- mem_write_chunks_v(pid, ia, ref, chunks) do
      :ok
    end
  end

  # TODO:test/low prio
  def dmp_memverify_rco(pid, ia, ref, data, max_len \\ 12) do
    with {:ok, read} = mem_read_chunks(pid, ia, ref, byte_size(data), max_len, <<>>),
         :ok <- validate(read == data, :not_equal) do
      :ok
    end
  end

  # TODO:test/low prio
  def dmp_memread_rco(pid, ia, ref, data, max_len \\ 12) do
    mem_read_chunks(pid, ia, ref, byte_size(data), max_len, <<>>)
  end

  # def dmp_usermemwrite_rco(pid) do
  # end

  # def dmp_usermemwrite_rcov(pid) do
  # end

  # def dmp_usermemverify_rco(pid) do
  # end

  # def dmp_usermemread_rco(pid) do
  # end

  # TODO unklar: if Property of management control is unknown to the Management Client
  #     -- nicht implementiert
  # def dmp_io_write_r(pid) do
  #   # TODO noch nicht impl. nur interessant fuer IO mit array-props.
  # end

  # def dmp_io_verify_r(pid) do
  #   # TODO noch nicht impl. nur interessant fuer IO mit array-props.
  # end

  # def dmp_io_read_r(pid) do
  #   # TODO noch nicht impl. nur interessant fuer IO mit array-props.
  # end

  @doc """

  example result: (both scan_io? and scan_prop? true)

  [
  o_idx  o_type   p_idx p_id
  {0,     0,     [{0,    1}, {1, 2}, ..., {14, 58}]},
  ...
  {11,    50003, [{0,    1}, ...]}
  ]

  one could generate a table like this from the result
  Example output

  o_idx | o_type | o_name*       | p_idx | p_id  | p_name*
  0       0        Device Object
                               00      01    | pid_obj_type
                               01      02    | Interface Object Name
  ...
                               14      58    | pid_dev_addr
  ...
  11    | 50003   | My Object
                               00      01    | pid_obj_type
  ...

  *) these need a lookup
  o_type -> o_name
  p_id -> p_name
  """

  # TODO This Management Procedure shall use the connection oriented or connectionless communication mode.
  def dm_io_scan_r(_pid, _ia, o_idx, scan_io: true, scan_props: _) when o_idx != 0,
    do: raise("o_idx shall be 0 when scanning io")

  def dm_io_scan_r(pid, ia, o_idx, scan_io: false, scan_props: scan_props),
    do: scan_io(pid, ia, o_idx, scan_props)

  def dm_io_scan_r(pid, ia, 0 = _o_idx, scan_io: true, scan_props: scan_props),
    do: scan_ios(pid, ia, 0, scan_props, [])

  # def dm_functionproperty_write_r(pid) do
  # end

  # trivial wenn vorher scan ("if Property of management control is unknown to the Management Client")
  # def dmp_loadstatemachinewrite_rco_io(pid) do
  # end

  def dmp_downloadloadablepart_rco_io(pid, ia, o_idx, ref, data, method \\ :mem, _add_lcs \\ []) do
    with :ok <- lsm_dispatch(pid, ia, o_idx, :unload, load_state(:unloaded)),
         :ok <- lsm_dispatch(pid, ia, o_idx, :start_loading, load_state(:loading)),
         # TODO _add_lcs
         :ok <- download(pid, ia, o_idx, ref, data, method),
         :ok <- lsm_dispatch(pid, ia, o_idx, :load_completed, load_state(:loaded)) do
      :ok
    end
  end

  # trivial wenn vorher scan ("if Property of management control is unknown to the Management Client")
  # def dm_loadstatemachineverify_r_io(pid) do
  # end

  # trivial wenn vorher scan ("if Property of management control is unknown to the Management Client")
  # def dmp_loadstatemachineread_r_io(pid) do
  # end

  # def dm_runstatemachinewrite(pid) do
  # end

  # def dmp_runstatemachinewrite_r_io(pid) do
  # end

  # def dm_runstatemachineverify(pid) do
  # end

  # def dmp_runstatemachineverify_r_io(pid) do
  # end

  # def dm_runstatemachineread(pid) do
  # end

  # def dmp_runstatemachineread_r_io(pid) do
  # end

  # def dmp_knxnet_ip_connect(pid) do
  # end

  # def dmp_io_write_ip(pid) do
  # end

  # def dmp_io_read_ip(pid) do
  # end

  # ----------------------------------------------------------------------------

  defp download(_pid, _ia, _o_idx, _ref, _data, :prop), do: raise("not implemented")

  defp download(pid, ia, _o_idx, ref, data, :mem) do
    dmp_memwrite_rcov(pid, ia, ref, data)
  end

  defp lsm_dispatch(pid, ia, o_idx, event, expect_state) do
    event_ = Knx.Ail.Lsm.encode_le(event)
    event = event_

    with {:ok, :prop_resp, state} <-
           Api.prop_write_x(pid, ia, o_idx, prop_id(:load_state_ctrl), event, :co),
         :ok <-
          poll_lsm_state(pid, ia, o_idx, state, <<expect_state>>) do
      :ok
    end
  end

  defp poll_lsm_state(_pid, _ia, _o_idx, <<load_state(:error)>>, _expect_state) do
     :error
  end

  defp poll_lsm_state(_pid, _ia, _o_idx, state, state) do
     :ok
  end

  defp poll_lsm_state(pid, ia, o_idx, _state, expect_state) do
    case Api.prop_read(pid, ia, o_idx, prop_id(:load_state_ctrl)) do
      {:api_result, resp} ->
        state = extract_prop_resp_data(resp)
        poll_lsm_state(pid, ia, o_idx, state, expect_state)

      error ->
        error
    end
  end

  def get_prop_id(pid, ia, o_idx, p_idx) do
    # :timer.sleep(3)
    case Api.prop_desc_read(pid, ia, o_idx, 0, p_idx) do
      {_, %{data: [_, pid, _, _, _, _, _, _]}} -> {:ok, :prop_id, pid}
      error -> error
    end
  end

  defp scan_ios(pid, ia, o_idx, scan_props?, results) do
    case scan_io(pid, ia, o_idx, scan_props?) do
      {:io, _, _, _} = result -> scan_ios(pid, ia, o_idx + 1, scan_props?, results ++ [result])
      _ -> results
    end
  end

  defp scan_io(pid, ia, o_idx, scan_props?) do
    with {:ok, :prop_id, id} when id != 0 <- get_prop_id(pid, ia, o_idx, 0),
         {:ok, :prop_resp, <<object_type::16>>} <- Api.prop_read_x(pid, ia, o_idx, id) do
      {
        :io,
        o_idx,
        object_type,
        if(scan_props?, do: scan_props(pid, ia, o_idx, 0, []), else: [])
      }
    end
  end

  defp scan_props(pid, ia, o_idx, p_idx, pids) do
    :timer.sleep(2)

    case get_prop_id(pid, ia, o_idx, p_idx) do
      {:ok, :prop_id, 0} -> pids
      {:ok, :prop_id, id} -> scan_props(pid, ia, o_idx, p_idx + 1, pids ++ [{p_idx, id}])
      error -> raise({error, p_idx, p_idx})
    end
  end

  defp mem_read_chunks(_, _, _, 0, _, read), do: {:ok, read}

  defp mem_read_chunks(pid, ia, ref, size, max_len, read) do
    read_size = if size > max_len, do: max_len, else: size

    case Api.mem_read(pid, ia, read_size, ref) do
      {_, _, %{apci: :mem_resp, data: data}} ->
        mem_read_chunks(pid, ia, ref + read_size, size - read_size, max_len, read <> data)

      error ->
        error
    end
  end

  defp enable_verify(pid, ia) do
    # "if P of device control is unknown to the Management Client"
    #   -- was soll das bringen, lass ich mal weg
    with {:ok, :prop_resp, device_ctrl} <-
           Api.prop_read_x(pid, ia, @device_object, prop_id(:device_ctrl)),
         device_ctrl <- P.decode(prop_id(:device_ctrl), nil, device_ctrl),
         device_ctrl <-
           P.encode(prop_id(:device_ctrl), nil, %{device_ctrl | verify_mode: true}),
         {:api_result, _} <-
           Api.prop_write(pid, ia, @device_object, prop_id(:device_ctrl), device_ctrl) do
      :ok
    end
  end

  # TODO --> toolbox
  defp chunk_binary(data, chunk_size, chunks) when byte_size(data) >= chunk_size do
    <<chunk::unit(8)-size(chunk_size)-binary, data::bits>> = data
    chunk_binary(data, chunk_size, chunks ++ [chunk])
  end

  defp chunk_binary(chunk, _, chunks), do: chunks ++ [chunk]

  defp mem_write_chunks(_, _, _, _, _, []), do: :ok

  defp mem_write_chunks(pid, ia, verify, ref, delay, [chunk | chunks]) do
    with {_, %{apci: :mem_write}} <- Api.mem_write(pid, ia, ref, chunk),
         :ok <- if(verify, do: verify_mem(pid, ia, ref, chunk), else: :ok) do
      dmp_delay(delay)
      mem_write_chunks(pid, ia, verify, ref + byte_size(chunk), delay, chunks)
    end
  end

  defp verify_mem(pid, ia, ref, data) do
    case Api.mem_read(pid, ia, byte_size(data), ref) do
      {_, %{apci: :mem_resp, data: [_, _, ^data]}} -> :ok
      _error -> {:error, :verify_failed}
    end
  end

  defp mem_write_chunks_v(_, _, _, []), do: :ok

  defp mem_write_chunks_v(pid, ia, ref, [chunk | chunks]) do
    case Api.mem_write_v(pid, ia, ref, chunk) do
      {_, %{apci: :mem_resp, data: [_, _, ^chunk]}} ->
        mem_write_chunks_v(pid, ia, ref + byte_size(chunk), chunks)

      error ->
        {:mem_write_v, :mem_write_v, error}
    end
  end

  defp extract_prop_resp_data(%{data: [_, _, _, _, data]}), do: data

  defp connect(pid, ia) do
    with {_, %{apci: :a_connect}} <- Api.connect(pid, ia),
         {_, :no_resp} <- Api.device_desc_read_x(pid, ia) do
      # TODO [2.3]
      # If no A_DeviceDescriptor_Response-PDU is received after time-out ⇒ IA_new is not occupied
      # --> warum? connect hat doch funktioniert?
      {:not_connected, :no_connection_established}
    else
      # TODO HACK -- need stacktrace
      {:error, :a_connect, :no_resp} ->
        {:not_connected, :connect_negative_conf}

      {:negative_lcon, :a_discon, :a_connect} ->
        {:not_connected, :connect_negative_conf}

      # TODO die discon-reasons muessen genauer sein, ich bekomme auch ein discon wenn ich zu nicht-existierender ia connecte
      # - ist das richtig?
      # - einzelne gruende fuer discon duerfen nicht nur ok? sein (event?)
      {:pdu, :a_discon, :a_connect} ->
        {:connected, {:error, :connection_refused}}

      {:ok, :device_desc_resp, desc} ->
        {:connected, {:ok, desc}}
    end
  end

  defp prog_if_differs(_pid, ia, ia), do: {:error, :ia_equal}

  defp prog_if_differs(pid, _ia, ia_new) do
    case Api.ind_addr_write(pid, ia_new) do
      {_, %{apci: :ind_addr_write}} -> :ok
      error -> error
    end
  end

  defp wait_for_prog_mode(pid, timeout) do
    :timer.sleep(5)
    case Api.ind_addr_read(pid, @nm_ind_addr_read_timeout) do
      {:api_multi_result, _, result} -> {:in_prog_mode, Enum.map(result, &Map.get(&1, :src))}

      # TODO HACK. warum funktioniert das ohne die neg-lcon clause bei nmindaddrread oben?
      {:error, _} -> wait_for_prog_mode(pid, timeout)
      {:negative_lcon, _, _} -> wait_for_prog_mode(pid, timeout)
    end
  end

  # defp scan_router(_pid, sna, found) when sna == 0xFF, do: found

  # defp scan_router(pid, sna, found) do
  #   with {_, _, %{apci: :a_connect}} <- Api.connect(pid, 0x100 * sna, 100),
  #
  #  TODO das ist falsch. lt standard wird das discon wird nicht vom client geschickt!!??
  #
  #        {_, _, %{apci: :a_discon}} <- Api.discon(pid) do
  #     [sna | found]
  #   else
  #     _ -> found
  #   end

  #   scan_router(pid, sna + 1, found)
  # end

  # defp scan_device(_pid, _sna, da, found) when da == 0xFF, do: found

  # defp scan_device(pid, sna, da, found) do
  #   with {_, _, %{apci: :a_connect}} <- Api.connect(pid, sna + da, 100),
  # TODO siehe router scan!
  #        {_, _, %{apci: :a_discon}} <- Api.discon(pid) do
  #     [da | found]
  #   else
  #     _ -> found
  #   end

  #   scan_device(pid, sna, da + 1, found)
  # end

  defp wait_until(fun, expect) do
    case fun.() do
      ^expect -> :ok
      _ -> wait_until(fun, expect)
    end
  end
end
