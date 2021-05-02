defmodule Knx.Mem do
  import Knx.Toolbox

  alias Knx.Frame, as: F
  alias Knx.State, as: S

  def handle({:mem, :conf, %F{}}, _state), do: []

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
         {:ok, data} <- read(number, addr) do
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
        %S{verify: verify, max_apdu_length: max_apdu_length} = state
      ) do
    with :ok <- validate(verify, :no_verify),
         :ok <- validate(max_apdu_length >= number + 3, :max_apdu_exceeded),
         _ <- write(addr, data),
         # [XVII]
         {:ok, ^data} <- read(number, addr) do
      {state, [al_req_impulse(:mem_resp, f, [number, addr, data])]}
    else
      # [XVIII]
      {:error, :no_verify} -> []
      # [XIX]
      {:error, :max_apdu_exceeded} -> []
      # [XX]
      {:error, :area_invalid} -> [al_req_impulse(:mem_resp, f, [0, addr, <<>>])]
    end
  end

  def read_table(addr, entry_size) do
    with {:ok, <<length::size(2)-unit(8)>>} <- read(2, addr),
         {:ok, <<table::bytes>>} <- read(length * entry_size, addr + 2) do
      {:ok, length, table}
    end
  end

  # NOTE: the application never writes the tables (only done by ETS) -> no write_table helper

  # ------------------------------------------------------------------------------

  defp read(number, addr) do
    mem = Cache.get(:mem)

    with :ok <- validate(area_valid?(mem, number, addr), :area_invalid) do
      {:ok, :binary.part(mem, addr, number)}
    end
  end

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

  # duplication
  defp al_req_impulse(apci, %F{service: service, src: dest}, apdu) do
    {:al, :req, %F{apci: apci, service: service, dest: dest, data: apdu}}
  end
end
