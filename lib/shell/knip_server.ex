defmodule Shell.KnipServer do
  use GenServer

  alias Shell.Server
  alias Knx.DataCemiFrame
  alias Knx.KnxnetIp.Endpoint, as: Ep
  alias Knx.KnxnetIp.KnxnetIpParameter
  alias Knx.KnxnetIp.IpInterface, as: Ip
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
    IO.inspect({address, port, inspect(data, base: :hex)}, label: :knipserver_rx)

    ep = %Ep{
      protocol_code: protocol_code(:udp),
      ip_addr: address,
      port: port
    }

    own_ip_address =
      Cache.get_obj(:knxnet_ip_parameter) |> KnxnetIpParameter.get_current_ip_addr()
       |> Ip.convert_number_to_ip()

    # own ip signals echo from sending routing indication via multicast
    #  -> create local conf for go-server
    data = if own_ip_address == address, do: convert_to_conf(data), else: data

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

  defp handle({:ip, :transmit, {ep, data}}, %{socket: socket} = state) do
    %Ep{ip_addr: ip, port: port} = ep

    :logger.info("[KS:] [>> eff] TX #{inspect({ip, port, data})}")
    :gen_udp.send(socket, ip, port, data)
    state
  end

  defp convert_to_conf(<<header::structure_length(:header)*8, cemi_frame::bits>>) do
    cemi_frame = DataCemiFrame.convert_message_code(cemi_frame, :l_data_con)
    <<header::structure_length(:header)*8, cemi_frame::bits>>
  end
end
