defmodule Knx.Mem do
  import Knx.Toolbox

  alias Knx.Frame, as: F
  alias Knx.State, as: S

  def handle({:mem, :conf, %F{} = frame}, _state), do: [{:mgmt, :conf, frame}]

  # TODO remove - API geht direkt auf :al
  def handle({:mem, :req, %F{apci: :mem_read} = frame}, %S{}) do
    [{:al, :req, frame}]
  end

  def handle({:mem, :req, %F{apci: :mem_write} = frame}, %S{}) do
    [{:al, :req, frame}]
  end

  def handle(
        {:mem, :ind, %F{apci: :mem_read, data: [number, addr]} = f},
        %S{max_apdu_length: max_apdu_length}
      ) do
    with :ok <- validate(max_apdu_length >= number + 3, :max_apdu_exceeded),
         {:ok, data} <- read(addr, number) do
      [al_req_impulse(:mem_resp, f, [number, addr, data])]
    else
      # [XV]
      {:error, :max_apdu_exceeded} -> []
      # [XVI]
      {:error, :area_invalid} -> [al_req_impulse(:mem_resp, f, [0, addr, <<>>])]
    end
  end

  def handle(
        {:mem, :ind, %F{apci: :mem_write, data: [number, addr, data]} = f},
        %S{verify: verify, max_apdu_length: max_apdu_length}
      ) do
    with :ok <- validate(max_apdu_length >= number + 3, :max_apdu_exceeded),
         _ <- write(addr, data),
         :ok <- validate(verify, :no_verify),
         # [XVII]
         {:ok, ^data} <- read(addr, number) do
      [al_req_impulse(:mem_resp, f, [number, addr, data])]
    else
      # [XVIII]
      {:error, :no_verify} -> []
      # [XIX]
      {:error, :max_apdu_exceeded} -> []
      # [XX]
      {:error, :area_invalid} -> [al_req_impulse(:mem_resp, f, [0, addr, <<>>])]
    end
  end

  def read(addr, number) do
    mem = Cache.get(:mem)

    with :ok <- validate(area_valid?(mem, number, addr), :area_invalid) do
      {:ok, :binary.part(mem, addr, number)}
    end
  end

  # ------------------------------------------------------------------------------

  defp write(addr, data) do
    mem = Cache.get(:mem)
    number = byte_size(data)

    with :ok <- validate(area_valid?(mem, number, addr), :area_invalid),
         mem <- binary_insert(mem, addr, data, number) do
      Cache.put(:mem, mem)
    end
  end

  defp area_valid?(_mem, _number, addr) when addr < 0, do: false

  defp area_valid?(mem, number, addr), do: byte_size(mem) >= addr + number

  # TODO duplication with io-server -> al.ex
  defp al_req_impulse(apci, %F{service: service, src: dest}, apdu) do
    {:al, :req, %F{apci: apci, service: service, dest: dest, data: apdu}}
  end

end
