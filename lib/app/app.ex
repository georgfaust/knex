defmodule Knx.App do
  use GenServer

  alias Knx

  @me __MODULE__

  def start_link(opts) do
    GenServer.start_link(@me, opts)
  end

  # --------------------------------------------------------------------

  @impl GenServer
  def init(device_serial: device_serial, params: params) do
    {:ok, %{device_serial: device_serial, params: params}}
  end

  @impl GenServer
  def handle_info({:app, :go_value, {go, [value]}}, %{device_serial: device_serial, params: params} = state) do
    IO.inspect({device_serial, go, value, params}, label: :app_go_value)
    {:noreply, state}
  end
end
