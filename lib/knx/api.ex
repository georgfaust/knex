defmodule Knx.Api do
  @moduledoc """

  !!! TODO was tun bei Aenderung PA und bestehender Verbindung?

    - results are gathered in a list
    - normally just one result is expected, so we return on the first expected result received
    - :multi - if this is set results are gathered until timeout is reached (set in override)
    - :timeout_ms - defines how long results are gathered (set in override)
    - :apci - the apci we expect as result
    - :prim - the primitive we expect as result

    these are not supported by the API:

    - not needed for basic functionality, will be implemented later TODO
      user_mem_write
      user_mem_read
      fun_prop_command
      fun_prop_state_read

    - TODO
      restart (its complicated)
      group_read (needs to be handled by :go not :al)
      group_write (needs to be handled by :go not :al)

    - for PEI only
      adc_read
      adc_resp

    - open medium/router only
      sys_nw_param_read:  :t_data_sys_broadcast,
      sys_nw_param_resp:  :t_data_sys_broadcast,
      sys_nw_param_write:  :t_data_sys_broadcast,
      nw_param_read:  :t_data_individual,
      nw_param_resp: %@me{:t_data_individual,
      nw_param_write:  :t_data_individual,

    - unused in management procedures
      user_mem_bit_write:  :t_data_con,
      user_manu_info_read:  :t_data_con,
      user_manu_info_resp:  :t_data_con,
      mem_bit_write:  :t_data_con,


  Knx.Api.call_(via(1), %{apci: :a_connect, dest: 5887})
  Knx.Api.call_(via(1), %{apci: :a_discon, dest: 5887})
                                                                      desc-type
  Knx.Api.call_(via(1), %{apci: :device_desc_read, dest: 5887, data: [0]})

                                                              key
  Knx.Api.call_(via(1), %{apci: :auth_req, dest: 5887, data: [4711]})
                                                               level key
  Knx.Api.call_(via(1), %{apci: :key_write, dest: 5887, data: [3,    0]})

  NOTE: set prog_mode with Shell.Server.set_prog_mode(via(1), 1)
  Knx.Api.call_(via(1), %{apci: :ind_addr_read})

                                                        address
  Knx.Api.call_(via(1), %{apci: :ind_addr_write, data: [100]})

                                                              serial
  Knx.Api.call_(via(1), %{apci: :ind_addr_serial_read, data: [2]})

                                                              serial addr
  Knx.Api.call_(via(1), %{apci: :ind_addr_serial_write, data: [2,    100]})

                                                              number, addr, data
  Knx.Api.call_(via(1), %{apci: :mem_write, dest: 5887, data: [2,     0,    <<0xAFFE::16>>]})

                                                             number, addr
  Knx.Api.call_(via(1), %{apci: :mem_read, dest: 5887, data: [5,     0]})

                                                                    o_idx, pid, p_idx
  Knx.Api.call_(via(1), %{apci: :prop_desc_read, dest: 5887, data: [0,     11,  0]})
  Knx.Api.call_(via(1), %{apci: :prop_desc_read, dest: 5887, data: [0,     0,   3]})

                                                                o_idx, pid, elems, start, data
  Knx.Api.call_(via(1), %{apci: :prop_write, dest: 5887, data: [0,     54,  1,     1,     1]})

                                                              o_idx, pid, elems, start
  Knx.Api.call_(via(1), %{apci: :prop_read, dest: 5887, data: [0,    11,  1,     1]})


  """
  alias Knx.Frame, as: F
  @me __MODULE__

  defstruct prim: :conf,
            apci: nil,
            timeout_ms: 50,
            multi: false,
            take: [:apci]

  def get_expect(apci) do
    expect = %{
      a_connect: nil,
      a_discon: nil,
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
      # restart:  :todo,
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

  @doc """
  generate a request to send and an expected result.
  fields can be overridden with `expect`. (eg %{expect: :mem_resp} for a verified `:mem_write`)
  """
  def call_(device_name, %{apci: apci} = frame, override \\ %{}) do
    case get_expect(apci) do
      :error ->
        {:error, :unknown_apci}

      expect ->
        frame = Map.merge(%F{service: Knx.Stack.Al.get_default_service(apci), data: []}, frame)
        impulse = {get_handler(apci), :req, frame}
        Shell.Server.api_call(device_name, impulse, Map.merge(expect, override))
    end
  end
end
