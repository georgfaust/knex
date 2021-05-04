defmodule Knx.ManagementProcedures do
  alias Knx.Api

  def nm_individualaddress_read(pid) do
    case ind_addr_read(pid, 3000) do
      {:api_multi_result, _, result} -> Enum.map(result, &Map.get(&1, :src))
      {:error, _} -> []
    end
  end

  def nm_individualaddress_write(pid, ia_new) do
    with :not_occupied <- occupied?(pid, ia_new),
         {:in_prog_mode, [ia]} <- wait_for_prog_mode(pid, 1000),
         :ok <- prog_if_differs(ia, ia_new),
         {_, _, %{apci: :a_connect}} <- connect(pid, ia_new),
         {_, %{apci: :device_desc_resp}} <- device_desc_read(pid, ia_new),
         # TODO
         {_, %{apci: :restart}} <- restart(pid, ia),
         _ <- discon(pid) do
      :ok
    else
      {:in_prog_mode, ia_addrs} -> {:error, :more_than_one_in_prog_mode, ia_addrs}
      error -> {:error, :unexpected, error}
    end
  end

  def nm_individualaddress_serialnumber_read() do
  end

  def nm_individualaddress_serialnumber_write() do
  end

  def nm_subnetworkdevices_scan() do
  end

  def nm_individualaddress_reset() do
  end

  def nm_individualaddress_check() do
  end

  def nm_serialnumberdefaultia_scan() do
  end

  def dm_connect() do
  end

  def dmp_connect_rco() do
  end

  def dmp_connect_rcl() do
  end

  def dm_disconnect() do
  end

  def dmp_disconnect_rco() do
  end

  def dm_identify() do
  end

  def dm_identify_rco2() do
  end

  def dm_authorize() do
  end

  def dmp_authorize_rco() do
  end

  def dm_setkey() do
  end

  def dm_setkey_rco() do
  end

  def dm_restart() do
  end

  def dm_restart_rcl() do
  end

  def dm_restart_rco() do
  end

  def dm_delay() do
  end

  def dmp_delay() do
  end

  def dm_progmode_switch() do
  end

  def dmp_progmodeswitch_rco() do
  end

  def dm_memwrite() do
  end

  def dmp_memwrite_rco() do
  end

  def dmp_memwrite_rcov() do
  end

  def dm_memverify() do
  end

  def dmp_memverify_rco() do
  end

  def dm_memread() do
  end

  def dmp_memread_rco() do
  end

  def dm_usermemwrite() do
  end

  def dmp_usermemwrite_rco() do
  end

  def dmp_usermemwrite_rcov() do
  end

  def dm_usermemverify() do
  end

  def dmp_usermemverify_rco() do
  end

  def dm_usermemread() do
  end

  def dmp_usermemread_rco() do
  end

  def dm_interfaceobjectwrite() do
  end

  def dmp_interfaceobjectwrite_r() do
  end

  def dm_interfaceobjectverify() do
  end

  def dmp_interfaceobjectverify_r() do
  end

  def dm_interfaceobjectread() do
  end

  def dmp_interfaceobjectread_r() do
  end

  def dm_interfaceobjectscan() do
  end

  def dmp_interfaceobjectscan_r() do
  end

  def dm_functionproperty_write_r() do
  end

  def dm_loadstatemachinewrite() do
  end

  def dmp_loadstatemachinewrite_rco_io() do
  end

  def dmp_downloadloadablepart_rco_io() do
  end

  def dm_loadstatemachineverify() do
  end

  def dm_loadstatemachineverify_r_io() do
  end

  def dm_loadstatemachineread() do
  end

  def dmp_loadstatemachineread_r_io() do
  end

  def dm_runstatemachinewrite() do
  end

  def dmp_runstatemachinewrite_r_io() do
  end

  def dm_runstatemachineverify() do
  end

  def dmp_runstatemachineverify_r_io() do
  end

  def dm_runstatemachineread() do
  end

  def dmp_runstatemachineread_r_io() do
  end

  def dmp_knxnet_ip_connect() do
  end

  def dmp_interfaceobjectwrite_ip() do
  end

  def dmp_interfaceobjectread_ip() do
  end

  # ---
  defp occupied?(pid, ia) do
    with {_, _, %{apci: :a_connect}} <- connect(pid, ia),
         {_, :no_resp} <- discon(pid),
         {_, :no_resp} <- device_desc_read(pid, ia) do
      :not_occupied
    else
      {_, :a_connect, :no_resp} ->
        :not_occupied

      {_, :device_desc_resp, _} ->
        discon(pid)
        :occupied

      _ ->
        :occupied
    end
  end

  defp restart(pid, ia) do
    Api.call_(pid, %{apci: :restart, dest: ia, data: [:TODO]})
  end

  defp ind_addr_read(pid, timeout) do
    Api.call_(pid, %{apci: :ind_addr_read}, %{multi: true, timeout_ms: timeout})
  end

  defp connect(pid, ia) do
    Api.call_(pid, %{apci: :a_connect, dest: ia})
  end

  defp discon(pid) do
    Api.call_(pid, %{apci: :a_discon})
  end

  defp device_desc_read(pid, ia) do
    Api.call_(pid, %{apci: :device_desc_read, dest: ia, data: [0]})
  end

  # TODO
  defp prog_if_differs(_ia, _ia_new) do
    # assert {:api_result, %{apci: :ind_addr_write}} ==
    #   Knx.Api.call_(via(1), %{apci: :ind_addr_write, data: [100]})
    :ok
  end

  defp wait_for_prog_mode(pid, timeout) do
    case ind_addr_read(pid, timeout) do
      {_, :ind_addr_resp, :no_resp} -> wait_for_prog_mode(pid, timeout)
      {_, :ind_addr_resp, result} -> {:in_prog_mode, Enum.map(result, &Map.get(&1, :src))}
    end
  end
end
