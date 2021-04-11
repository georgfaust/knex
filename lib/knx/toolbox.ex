defmodule Knx.Toolbox do
  def authorize(current, required), do: validate(current <= required, :unauthorized)

  def validate(true, _error_reason), do: :ok
  def validate(false, error_reason), do: {:error, error_reason}
  def validate(:error, error_reason), do: {:error, error_reason}
  def validate(value, _error_reason), do: value

  def insert_list(lst, insert_lst, at) do
    bef = Enum.take(lst, at)
    {_, aft} = Enum.split(lst, at + length(insert_lst))
    bef ++ insert_lst ++ aft
  end

  def binary_insert(bin, at, data, size) do
    <<bin_before::bytes-unit(8)-size(at), _::unit(8)-size(size), bin_after::bytes>> = bin
    bin_before <> data <> bin_after
  end

  def bool_to_int(true), do: 1
  def bool_to_int(false), do: 0

  def zero_based(index), do: index - 1
  def one_based(index), do: index + 1
end
