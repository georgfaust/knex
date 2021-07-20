defmodule Knx.Ail.IoServer do
  import Knx.Toolbox

  alias Knx.Ail.Property, as: P
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  require Knx.Defs
  import Knx.Defs

  alias Knx.Ail.Device

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

  def handle({:io, :conf, %F{} = frame}, _state), do: [{:mgmt, :conf, frame}]

  def handle({:io, :ind, %F{apci: apci} = frame}, state)
      when apci in @device_object_apcis,
      do: load_and_serve(object_type(:device), frame, state)

  def handle({:io, :ind, %F{data: [o_idx | _]} = frame}, state),
    do: load_and_serve(o_idx, frame, state)

  # def handle(_, _), do: []

  defp load_and_serve(o_idx, frame, %S{access_lvl: access_lvl} = state) do
    props = Cache.get_obj_idx(o_idx)

    {impulses, new_props} = serve(props, access_lvl, frame)

    # TODO make it not suck so much
    state =
      if props != new_props do
        Cache.put_obj_idx(o_idx, new_props)
        # TODO hack
        if o_idx == 0 do
          Knx.State.update_from_device_props(state, new_props)
        else
          state
        end
      else
        state
      end

    {state, impulses}
  end

  # --------------------------------------

  defp serve(props, _, %F{apci: :prop_desc_read, data: [o_idx, pid, p_idx]} = f) do
    apdu =
      case P.get_prop(props, pid, p_idx) do
        {:ok, idx, pdt, %P{id: id, write: write, max: max, r_lvl: r_lvl, w_lvl: w_lvl}} ->
          [o_idx, id, idx, bool_to_int(write), pdt, max, r_lvl, w_lvl]

        {:error, _} ->
          [o_idx, pid, p_idx, 0, 0, 0, 0, 0]
      end

    {[al_req_impulse(:prop_desc_resp, f, apdu)], props}
  end

  defp serve(props, access_lvl, %F{apci: :prop_read, data: [o_idx, pid, elems, start]} = f) do
    apdu =
      case P.read_prop(props, access_lvl, pid: pid, elems: elems, start: start) do
        {:ok, _p_idx, data} ->
          [o_idx, pid, elems, start, data]

        {:error, _reason} ->
          :logger.warning("can't read o_idx: #{o_idx} pid: #{pid}")
          [o_idx, pid, 0, start, <<>>]
      end

    {[al_req_impulse(:prop_resp, f, apdu)], props}
  end

  defp serve(props, access_lvl, %F{apci: :prop_write, data: [o_idx, pid, elems, start, data]} = f) do
    {props, apdu, impulses} =
      case P.write_prop(o_idx, props, access_lvl, pid: pid, elems: elems, start: start, data: data) do
        {:ok, props, %P{id: id}, impulses} ->
          {props, [o_idx, id, elems, start, data], impulses}

        {:error, _reason} ->
          {nil, [o_idx, pid, 0, start, <<>>], []}
      end

    {impulses ++ [al_req_impulse(:prop_resp, f, apdu)], props}
  end

  defp serve(props, _, %F{apci: :ind_addr_write, data: [address]}) do
    props = if Device.prog_mode?(props), do: Device.set_address(props, address), else: props
    {[], props}
  end

  defp serve(props, _, %F{apci: :ind_addr_read} = f) do
    impulses = if Device.prog_mode?(props), do: [al_req_impulse(:ind_addr_resp, f)], else: []
    {impulses, props}
  end

  defp serve(props, _, %F{apci: :ind_addr_serial_write, data: [serial, address]}) do
    props =
      if Device.serial_matches?(props, serial),
        do: Device.set_address(props, address),
        else: props

    {[], props}
  end

  defp serve(props, _, %F{apci: :ind_addr_serial_read, data: [serial]} = f) do
    impulses =
      if Device.serial_matches?(props, serial) do
        # domain address is only relevant for open media, set to 0 for TP
        domain_address = 0
        [al_req_impulse(:ind_addr_serial_resp, f, [serial, domain_address])]
      else
        []
      end

    {impulses, props}
  end

  defp serve(props, _, %F{apci: :device_desc_read, data: [0 = desc_type]} = f) do
    {[al_req_impulse(:device_desc_resp, f, [desc_type, <<Device.get_desc(props)::16>>])], props}
  end

  defp serve(_props, _, %F{apci: :device_desc_read, service: _service, data: [_desc_type]}) do
    raise("TODO long frames needed for other desc types")
  end

  defp serve(_, _, frame) do
    :logger.error("[IoServer] no handler for #{inspect(frame)}")
    nil
  end

  # --------------------------------------

  defp al_req_impulse(apci, %F{service: service, src: dest}, apdu \\ nil) do
    {:al, :req, %F{apci: apci, service: service, dest: dest, data: apdu}}
  end
end
