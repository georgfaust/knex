defmodule Knx.Restart do
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  require Knx.Defs
  import Knx.Defs

  # - TODO
  #   - send an appropriate LM_Reset.ind message through the EMI interface
  #   - reset its KNX communication system
  #       was ausser einem discon bei dem seq zurueckgesetzt werden und stored und deferred geloescht werden

  def handle({:restart, :conf, %F{} = frame}, _state), do: [{:mgmt, :conf, frame}]

  def handle({:restart, :ind, %F{apci: :restart_basic, data: []}}, %S{auth: auth} = state) do
    Cache.update_obj(:device_object, &Knx.Ail.Device.set_prog_mode(&1, 0))

    # TODO crash
    # Cache.update_obj(:device_object, &Knx.Ail.Device.update_device_ctrl(&1, %{safe_state: false}))

    {
      %S{state | auth: Knx.Auth.de_auth(auth)},
      [{:al, :req, %F{apci: :a_discon}}]
    }
  end

  # def handle(
  #       {:restart, :ind, %F{apci: :restart_master, service: service, data: data}},
  #       %S{} = state
  #     ) do
  #   {error_code, process_time} = restart_master(data)

  #   [
  #     {:al, :req,
  #      %F{apci: :restart_resp, service: service, dest: dest, data: [error_code, process_time]}}
  #   ]
  # end

  # ---

  # defp restart_master([erase_code, channel_number]) do
  # end
end
