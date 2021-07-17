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
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  @impl GenServer
  def init(port) do
    {:ok, socket} =
      :gen_udp.open(
        port,
        [:binary, {:add_membership, {@knx_multicast, {0, 0, 0, 0}}}]
      )

    {:ok, %{socket: socket}}
  end

  def dispatch(impulse) do
    GenServer.cast(__MODULE__, impulse)
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

  # @impl GenServer
  # def handle_cast({_layer, _prim, _data} = impulse, state) do
  #   :logger.info("[KnipServer] [>> eff] #{inspect(impulse)}")
  #   {:noreply, state}
  # end

  @impl GenServer
  def handle_cast(impulse, state) do
    # :logger.info("[KS:] [>> eff] #{inspect(impulse)}")
    {:noreply, handle(impulse, state)}
  end

  defp handle({:ethernet, :transmit, {ep, data}}, %{socket: socket} = state) do
    %Ep{ip_addr: ip, port: port} = ep
    # HACK -> TODO leon: immer tuple in %EP{}
    ip = case ip do
      {_, _, _, _} = ip -> ip
      ip -> convert_number_to_ip(ip)
    end
    :logger.info("[KS:] [>> eff] TX #{inspect({ip, port, data})}")
    :gen_udp.send(socket, ip, port, data)
    state
  end

  defp  convert_number_to_ip(ip) do
    use Bitwise
    {(ip >>> 24) &&& 0xFF, (ip >>> 16) &&& 0xFF, (ip >>> 8) &&& 0xFF, ip &&& 0xFF}
  end
end
