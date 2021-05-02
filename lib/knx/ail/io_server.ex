defmodule Knx.Ail.IoServer do
  import Knx.Toolbox

  alias Knx.Ail.Property, as: P
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  alias Knx.Ail.{Device}

  @device_object_apcis [
    :ind_addr_write,
    :ind_addr_read,
    :user_manu_info_read,
    :fun_prop_command,
    :fun_prop_state_read,
    :device_desc_read,
    :device_desc_resp,
    :ind_addr_serial_write,
    :ind_addr_serial_read
  ]

  def handle({:io, :conf, %F{}}, _state), do: []

  def handle({:io, :ind, %F{apci: apci} = frame}, state)
      when apci in @device_object_apcis,
      do: load_and_serve(0, frame, state)

  def handle({:io, :ind, %F{data: [o_idx | _]} = frame}, state),
    do: load_and_serve(o_idx, frame, state)

  # def handle(_, _), do: []

  defp load_and_serve(o_idx, frame, %S{access_lvl: access_lvl} = state) do
    props = Cache.get({:objects, o_idx})

    {impulses, props} =
      case serve(props, access_lvl, frame) do
        nil -> {[], props}
        {nil, nil} -> {[], props}
        {nil, new_props} -> {[], new_props}
        {impulse, new_props} -> {[impulse], new_props}
        impulse -> {[impulse], props}
      end

    Cache.put({:objects, o_idx}, props)

    {impulses, state}
  end

  # --------------------------------------

  defp serve(props, _, %F{apci: :prop_desc_read, service: service, data: [o_idx, pid, p_idx]}) do
    apdu =
      case P.get_prop(props, pid, p_idx) do
        {:ok, idx, pdt, %P{id: id, write: write, max: max, r_lvl: r_lvl, w_lvl: w_lvl}} ->
          [o_idx, id, one_based(idx), bool_to_int(write), pdt, max, r_lvl, w_lvl]

        {:error, _reason} ->
          [o_idx, pid, p_idx, 0, 0, 0, 0, 0]
      end

    al_req_impulse(:prop_desc_resp, service, apdu)
  end

  defp serve(props, access_lvl, %F{
         apci: :prop_read,
         service: service,
         data: [o_idx, pid, elems, start]
       }) do
    apdu =
      case P.read_prop(props, access_lvl, pid: pid, elems: elems, start: start) do
        {:ok, _p_idx, data} ->
          [o_idx, pid, elems, start, data]

        {:error, _reason} ->
          [o_idx, pid, 0, start, <<>>]
      end

    al_req_impulse(:prop_resp, service, apdu)
  end

  defp serve(props, access_lvl, %F{
         apci: :prop_write,
         service: service,
         data: [o_idx, pid, elems, start, data]
       }) do
    {props, apdu} =
      case P.write_prop(o_idx, props, access_lvl, pid: pid, elems: elems, start: start, data: data) do
        {:ok, props, %P{id: id}} ->
          {props, [o_idx, id, elems, start, data]}

        {:error, _reason} ->
          {nil, [o_idx, pid, 0, start, <<>>]}
      end

    {al_req_impulse(:prop_resp, service, apdu), props}
  end

  defp serve(props, _, %F{apci: :ind_addr_write, data: [address]}) do
    props = if Device.prog_mode?(props), do: Device.set_address(props, address)
    {nil, props}
  end

  defp serve(props, _, %F{apci: :ind_addr_read, service: service}) do
    if Device.prog_mode?(props), do: al_req_impulse(:ind_addr_resp, service)
  end

  defp serve(props, _, %F{apci: :ind_addr_serial_write, data: [serial, address]}) do
    props = if Device.serial_matches?(props, serial), do: Device.set_address(props, address)
    {nil, props}
  end

  defp serve(props, _, %F{apci: :ind_addr_serial_read, service: service, data: [serial]}) do
    if Device.serial_matches?(props, serial) do
      # domain address is only relevant for RF and PL, set to 0 for TP
      domain_address = 0
      al_req_impulse(:ind_addr_serial_resp, service, [serial, domain_address])
    end
  end

  defp serve(props, _, %F{apci: :device_desc_read, service: service, data: [0 = desc_type]}) do
    al_req_impulse(:device_desc_resp, service, [desc_type, <<Device.get_desc(props)::16>>])
  end

  defp serve(_props, _, %F{apci: :device_desc_read, service: _service, data: [_desc_type]}) do
    raise("TODO long frames needed for other desc types")
  end

  defp serve(_, _, frame) do
    :logger.error("[IoServer] no handler for #{inspect frame}")
    nil
  end

  # --------------------------------------

  defp al_req_impulse(apci, service, apdu \\ nil) do
    {:al, :req, %F{apci: apci, service: service, data: apdu}}
  end
end
