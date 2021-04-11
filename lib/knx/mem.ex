defmodule Knx.Mem do
  import Knx.Toolbox

  def read_table(mem, ref, entry_size) do
    with {:ok, <<length::size(2)-unit(8)>>} <- read(mem, ref, 2),
         {:ok, <<table::bytes>>} <- read(mem, ref + 2, length * entry_size) do
      {:ok, length, table}
    end
  end

  # NOTE: the application never writes the tables (only done by ETS) -> no write_table helper

  def read(mem, ref, size) do
    with :ok <- validate(area_valid?(mem, ref, size), :area_invalid) do
      {:ok, :binary.part(mem, ref, size)}
    end
  end

  def write(mem, ref, data) do
    size = byte_size(data)

    with :ok <- validate(area_valid?(mem, ref, size), :area_invalid) do
      {:ok, binary_insert(mem, ref, data, size)}
    end
  end

  # ------------------------------------------------------------------------------
  defp area_valid?(_mem, ref, _size) when ref < 0, do: false

  defp area_valid?(mem, ref, size), do: byte_size(mem) >= ref + size
end
