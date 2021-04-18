defmodule Knx.Mem do
  import Knx.Toolbox

  alias Knx.Frame, as: F
  alias Knx.State, as: S
  alias Knx.Ail.Device

  def handle({:mem, :req, %F{apci: :mem_read} = frame}, %S{}) do
    [{:al, :req, frame}]
  end

  def handle({:mem, :req, %F{apci: :mem_write} = frame}, %S{}) do
    [{:al, :req, frame}]
  end

  def handle(
        {:mem, :ind, %F{apci: :mem_read, data: [number, addr]}},
        %S{mem: mem, objects: objects}
      ) do

    {:ok, device_props} = Map.fetch(objects, Device.get_object_index())
    <<_, max_apdu_length>> = Device.get_max_apdu_length(device_props)

    with :ok <- validate(max_apdu_length >= number + 3, :max_apdu_exceeded),
      {:ok, data} <- read(mem, number, addr)
    do
      [{:al, :req, %F{apci: :mem_resp, data: [number, addr, data]}}]
    else
      # [XV]
      {:error, :max_apdu_exceeded} -> []
      # [XVI]
      {:error, :area_invalid} -> [{:al, :req, %F{apci: :mem_resp, data: [0, addr, <<>>]}}]
    end
  end

  def handle(
        {:mem, :ind, %F{apci: :mem_write, data: [number, addr, data]}},
        %S{mem: mem, objects: objects} = state
      ) do

    {:ok, device_props} = Map.fetch(objects, Device.get_object_index())
    <<_, max_apdu_length>> = Device.get_max_apdu_length(device_props)

    with :ok <- validate(Device.verify?(device_props), :no_verify),
      :ok <- validate(max_apdu_length >= number + 3, :max_apdu_exceeded),
      {:ok, mem} <- write(mem, addr, data),
      # [XVII]
      {:ok, ^data} <- read(mem, number, addr)
    do
        {
          %{state | mem: mem},
          [{:al, :req, %F{apci: :mem_resp, data: [number, addr, data]}}]
        }
    else
      # [XVIII]
      {:error, :no_verify} -> []
      # [XIX]
      {:error, :max_apdu_exceeded} -> []
      # [XX]
      {:error, :area_invalid} -> [{:al, :req, %F{apci: :mem_resp, data: [0, addr, <<>>]}}]
    end
  end

  def read_table(mem, addr, entry_size) do
    with {:ok, <<length::size(2)-unit(8)>>} <- read(mem, 2, addr),
         {:ok, <<table::bytes>>} <- read(mem, length * entry_size, addr + 2) do
      {:ok, length, table}
    end
  end

  # NOTE: the application never writes the tables (only done by ETS) -> no write_table helper

  # ------------------------------------------------------------------------------

  defp read(mem, number, addr) do
    with :ok <- validate(area_valid?(mem, number, addr), :area_invalid) do
      {:ok, :binary.part(mem, addr, number)}
    end
  end

  defp write(mem, addr, data) do
    number = byte_size(data)
    with :ok <- validate(area_valid?(mem, number, addr), :area_invalid) do
      {:ok, binary_insert(mem, addr, data, number)}
    end
  end

  defp area_valid?(_mem, _number, addr) when addr < 0, do: false

  defp area_valid?(mem, number, addr), do: byte_size(mem) >= addr + number
end
