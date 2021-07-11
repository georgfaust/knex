defmodule Shell.KnipServer do
  use GenServer

  alias Shell.Server
  alias Knx.KnxnetIp.Endpoint, as: Ep
  require Knx.Defs
  import Knx.Defs

  # {:ok, socket} =
  #   :gen_udp.open(3671, [
  #     :binary,
  #     {:active, true},
  #     {:add_membership, {{224, 0, 23, 12}, {0, 0, 0, 0}}}
  #   ])

  @knx_multicast {224, 0, 23, 12}

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port: port)
  end

  @impl GenServer
  def init(port: port) do
    {:ok, socket} =
      :gen_udp.open(
        port,
        [:binary, {:add_membership, {@knx_multicast, {0, 0, 0, 0}}}]
      )

    {:ok, %{socket: socket}}
  end

  @impl GenServer
  def handle_info({:udp, _socket, address, port, data}, %{} = state) do
    IO.inspect({address, port, data}, label: :knipserver_rx)

    ep = %Ep{
      protocol_code: protocol_code(:udp),
      ip_addr: address,
      port: port
    }

    Server.dispatch(nil, {:knip, :from_ip, {ep, data}})

    {:noreply, state}
  end
end
