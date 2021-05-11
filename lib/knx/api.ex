# “Commons Clause” License Condition v1.0

# The Software is provided to you by the Licensor under the License, as defined below, subject to the following condition.
# Without limiting other conditions in the License, the grant of rights under the License will not include, and the License does not grant to you, the right to Sell the Software.
# For purposes of the foregoing, “Sell” means practicing any or all of the rights granted to you under the License to provide to third parties, for a fee or other consideration (including without limitation fees for hosting or consulting/ support services related to the Software), a product or service whose value derives, entirely or substantially, from the functionality of the Software. Any license notice or attribution required by the License must also include this Commons Clause License Condition notice.

# Software: KNeX - API
# License: MIT
# Licensor: Sebastian Fey

defmodule Knx.Api do
  @moduledoc """

  !!! TODO was tun bei Aenderung PA und bestehender Verbindung?

    - results are gathered in a list
    - normally just one result is expected, so we return on the first expected result received
    - :multi - if this is set results are gathered until timeout is reached (set in opts)
    - :timeout_ms - defines how long results are gathered (set in opts)
    - :apci - the apci we expect as result
    - :prim - the primitive we expect as result

    these are not supported by the API:

    - not needed for basic functionality, will be implemented later TODO
      user_mem_write
      user_mem_read
      fun_prop_command
      fun_prop_state_read

    - TODO
      group_read (done, untested)
      group_write (done, untested)

    - for PEI only
      adc_read
      adc_resp

    - open medium/router only
      sys_nw_param_read:  :t_data_sys_broadcast,
      sys_nw_param_resp:  :t_data_sys_broadcast,
      sys_nw_param_write:  :t_data_sys_broadcast,
      nw_param_read:  :t_data_ind,
      nw_param_resp: %@me{:t_data_ind,
      nw_param_write:  :t_data_ind,

    - unused in management procedures
      user_mem_bit_write:  :t_data_con,
      user_manu_info_read:  :t_data_con,
      user_manu_info_resp:  :t_data_con,
      mem_bit_write:  :t_data_con,

  """
  alias Knx.Frame, as: F
  @me __MODULE__

  defstruct prim: :conf,
            apci: nil,
            timeout_ms: 100,
            multi: false,
            take: [:apci]

  # --- con/discon

  def connect(pid, ia, timeout \\ 50) do
    call_(pid, %{apci: :a_connect, dest: ia}, nil, %{timeout_ms: timeout})
  end

  def discon(pid) do
    call_(pid, %{apci: :a_discon})
  end

  # --- groups
  def group_write(pid, asap, data) do
    call_(pid, %{apci: :group_write, asap: asap, data: [data]})
  end

  # --- device_desc

  def device_desc_read(pid, ia, mode \\ :co) do
    call_(pid, %{apci: :device_desc_read, dest: ia, data: [0]}, mode)
  end

  def device_desc_read_x(pid, ia, mode \\ :co) do
    case device_desc_read(pid, ia, mode) do
      {:api_result, %{apci: apci, data: [typ, desc]}} -> {:ok, apci, {typ, desc}}
      error -> error
    end
  end

  # --- ind_addr

  def ind_addr_serial_read(pid, sn) do
    call_(pid, %{apci: :ind_addr_serial_read, data: [sn]})
  end

  def ind_addr_read(pid, timeout) do
    call_(pid, %{apci: :ind_addr_read}, nil, %{multi: true, timeout_ms: timeout})
  end

  def ind_addr_write(pid, ia) do
    Knx.Api.call_(pid, %{apci: :ind_addr_write, data: [ia]})
  end

  # --- prop

  def prop_desc_read(pid, ia, o_idx, id, idx, mode \\ :co, opts \\ %{}) do
    call_(pid, %{apci: :prop_desc_read, dest: ia, data: [o_idx, id, idx]}, mode, opts)
  end

  def prop_read(pid, ia, o_idx, id, mode \\ :co, opts \\ %{}) do
    call_(pid, %{apci: :prop_read, dest: ia, data: [o_idx, id, 1, 1]}, mode, opts)
  end

  def prop_read_x(pid, ia, o_idx, id, mode \\ :co) do
    case prop_read(pid, ia, o_idx, id, mode) do
      {:api_result, %{data: [_, _, _, _, data]}} -> {:ok, :prop_resp, data}
      error -> error
    end
  end

  def prop_write(pid, ia, o_idx, id, data, mode \\ :co) do
    call_(pid, %{apci: :prop_write, dest: ia, data: [o_idx, id, 1, 1, data]}, mode)
  end

  def prop_write_x(pid, ia, o_idx, id, data, mode \\ :co) do
    case prop_write(pid, ia, o_idx, id, data, mode) do
      {:api_result, %{data: [_, _, _, _, data]}} -> {:ok, :prop_resp, data}
      error -> error
    end
  end

  # --- funprop
  # TODO

  # --- mem

  def mem_write(pid, ia, ref, data, mode \\ :co) do
    call_(pid, %{apci: :mem_write, dest: ia, data: [byte_size(data), ref, data]}, mode)
  end

  def mem_write_v(pid, ia, ref, data, mode \\ :co) do
    call_(
      pid,
      %{apci: :mem_write, dest: ia, data: [byte_size(data), ref, data]},
      mode,
      %{apci: :mem_resp, prim: :ind, take: [:apci, :data]}
    )
  end

  def mem_read(pid, ia, number, ref, mode \\ :co) do
    call_(pid, %{apci: :mem_read, dest: ia, data: [number, ref]}, mode)
  end

  # --- restart

  def restart(pid, ia, :basic, mode \\ :co) do
    call_(pid, %{apci: :restart_basic, dest: ia}, mode)
  end

  # ---

  def get_expect(apci) do
    expect = %{
      # TODO discon muss moegliches result sein,
      # ist aber OK wenn das nicht kommt und dafuer :conf
      # --> schauen ob das woanders aehnlich vorkommen kann
      # --> JA! discon kann ja als Antwort auf ALLE tdatacon kommen!
      #     zb bei Authorize "A_Disconnect.ind ⇒ error: connection was broken down"
      a_connect: nil,
      a_discon: nil,
      restart_basic: nil,
      device_desc_read: :device_desc_resp,
      auth_req: :auth_resp,
      key_write: :key_resp,
      ind_addr_read: {:ind_addr_resp, [:src, :apci]},
      ind_addr_write: nil,
      ind_addr_serial_read: {:ind_addr_serial_resp, [:src, :apci, :data]},
      ind_addr_serial_write: nil,
      mem_write: nil,
      mem_read: :mem_resp,
      # user_mem_write: nil,
      # user_mem_read: :user_mem_resp,
      prop_desc_read: :prop_desc_resp,
      prop_write: :prop_resp,
      prop_read: :prop_resp,
      # fun_prop_command: :fun_prop_state_resp,
      # fun_prop_state_read: :fun_prop_state_resp
      group_read: :group_resp,
      group_write: nil
    }

    case Map.fetch(expect, apci) do
      {:ok, nil} -> %@me{apci: apci}
      {:ok, {resp_apci, take}} -> %@me{apci: resp_apci, prim: :ind, take: take}
      {:ok, resp_apci} -> %@me{apci: resp_apci, prim: :ind, take: [:apci, :data]}
      error -> error
    end
  end

  def get_handler(apci) do
    handler = %{
      group_read: :go,
      group_write: :go
    }

    Map.get(handler, apci, :al)
  end

  def call_(device_name, %{apci: apci} = frame, mode \\ nil, opts \\ %{}) do
    case get_expect(apci) do
      :error ->
        {:error, :unknown_apci, apci}

      expect ->
        service = Knx.Stack.Al.get_default_service(apci, get_service(mode))
        frame = Map.merge(%F{service: service, data: []}, frame)
        impulse = {get_handler(apci), :req, frame}
        Shell.Server.api_call(device_name, impulse, Map.merge(expect, opts))
    end
  end

  # ---

  defp get_service(:co), do: :t_data_con
  defp get_service(:cl), do: :t_data_ind
  defp get_service(_), do: nil
end
