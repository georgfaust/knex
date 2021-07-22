defmodule Knx.Ail.Property do
  import Knx.Defs
  require Knx.Defs

  # TODO darf nicht ueber ende der liste lesen!

  defstruct id: nil,
            pdt: nil,
            values: [],
            max: 1,
            write: false,
            r_lvl: 3,
            w_lvl: 0

  @pdt_lengths %{
    ctrl: %{length: 1, write_length: 10},
    char: %{length: 1},
    unsigned_char: %{length: 1},
    int: %{length: 2},
    unsigned_int: %{length: 2},
    knx_float: %{length: 2},
    date: %{length: 3},
    time: %{length: 3},
    long: %{length: 4},
    unsigned_long: %{length: 4},
    float: %{length: 4},
    double: %{length: 8},
    char_block: %{length: 10},
    poll_group_setting: %{length: 3},
    short_char_block: %{length: 5},
    date_time: %{length: 8},
    # TODO
    # variable_length: %{length: nil, write_length: nil},
    generic_01: %{length: 1},
    generic_02: %{length: 2},
    generic_03: %{length: 3},
    generic_04: %{length: 4},
    generic_05: %{length: 5},
    generic_06: %{length: 6},
    generic_07: %{length: 7},
    generic_08: %{length: 8},
    generic_09: %{length: 9},
    generic_10: %{length: 10},
    generic_11: %{length: 11},
    generic_12: %{length: 12},
    generic_13: %{length: 13},
    generic_14: %{length: 14},
    generic_15: %{length: 15},
    generic_16: %{length: 16},
    generic_17: %{length: 17},
    generic_18: %{length: 18},
    generic_19: %{length: 19},
    generic_20: %{length: 20},
    utf8: %{length: 3},
    version: %{length: 2},
    alarm_info: %{length: 6},
    binary_information: %{length: 3},
    bitset8: %{length: 1},
    bitset16: %{length: 3},
    enum8: %{length: 3},
    scaling: %{length: 1},
    ne_vl: %{length: 3},
    ne_fl: %{length: 3},
    function: %{length: 3},
    escape: %{length: 3}
  }

  import Knx.Toolbox

  @me __MODULE__

  def new(pid, values, max: max, write: w, r_lvl: r_lvl, w_lvl: w_lvl) do
    %@me{
      id: prop_id(pid),
      pdt: pid_pdt(pid),
      values: values,
      max: max,
      write: w,
      r_lvl: r_lvl,
      w_lvl: w_lvl
    }
  end

  def write_prop(o_idx, props, access_lvl, pid: pid, elems: elems, start: start, data: data) do

    with {:ok, prop_index, _, %@me{pdt: pdt_atom} = prop} <- get_prop(props, pid),
         :ok <- validate(start - 1 + elems <= prop.max, :array_index_out_of_bounds),
         :ok <- authorize(access_lvl, prop.w_lvl),
         values <- decode_into_list(pid, pdt_atom, data),
         {:ok, %@me{} = prop, impulses} <-
           write_prop_({o_idx, pdt_atom, pid}, prop, elems, start, values) do
      props = List.replace_at(props, prop_index, prop)
      {:ok, props, prop, impulses}
    end
  end

  def read_prop(props, access_lvl, encode? \\ true, pid: pid, elems: elems, start: start) do
    with {:ok, prop_index, _, %@me{pdt: pdt_atom} = prop} <- get_prop(props, pid),
         :ok <- authorize(access_lvl, prop.r_lvl),
         {:ok, values} <- read_prop_(prop, elems, start),
         data <- if(encode?, do: encode_list(pid, pdt_atom, values), else: values) do
      {:ok, prop_index, data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def get_prop(props, pid, prop_index \\ 0)
  def get_prop(props, _pid, _prop_index) when not is_list(props), do: {:error, :no_props}

  def get_prop(props, pid, prop_index) do
    with {:ok, prop_index} <- get_prop_index(props, pid, prop_index),
         {:ok, %@me{pdt: pdt_atom} = prop} <-
           validate(Enum.fetch(props, prop_index), :prop_invalid) do
      {:ok, prop_index, pdt_id(pdt_atom), prop}
    end
  end

  # - helper -------------------------------------------------------------------------------------

  def read_prop_value(props, pid) do
    case read_prop(props, 0, false, pid: prop_id(pid), elems: 1, start: 1) do
      {:ok, _, values} -> hd(values)
      error -> error
    end
  end

  def write_prop_value(props, pid, data) do
    {:ok, props, _, _} =
      write_prop(nil, props, 0, pid: prop_id(pid), elems: 1, start: 1, data: data)

    props
  end

  # - private -------------------------------------------------------------------------------------

  # [II]
  defp write_prop_(_, prop, 1 = _elems, 0 = _start, [0] = _data),
    do: {:ok, %{prop | values: []}, []}

  defp write_prop_(_, _prop, _elems, 0 = _start, _data),
    do: {:error, :argument_error}

  defp write_prop_(_, _prop, elems, _start, data) when length(data) != elems,
    do: {:error, :argument_error_data_length, {data, elems}}

  defp write_prop_({o_idx, pdt, pid}, prop, 1, 1, data)
       when pdt in [:ctrl, :function] do
    case Knx.Ail.PropertyFunction.handle(o_idx, pid, prop, data) do
      {:ok, result, impulses} ->
        {:ok, %{prop | values: result}, impulses}

      {:error, result} ->
        {:ok, %{prop | values: result}, []}
    end
  end

  defp write_prop_(_, %{values: values} = prop, _elems, start, data),
    do: {:ok, %{prop | values: insert_list(values, data, start - 1)}, []}

  defp read_prop_(_, 0 = _elems, 0 = _start), do: {:error, :argument_error}

  defp read_prop_(%{values: values}, _elems, 0 = _start), do: {:ok, [length(values)]}

  defp read_prop_(%{values: values}, elems, start) do
    result = Enum.slice(values, start - 1, elems)

    case length(result) do
      0 -> {:error, :nothing_read}
      _ -> {:ok, result}
    end
  end

  defp get_prop_index(_props, 0 = _id, index), do: {:ok, index}

  defp get_prop_index(props, id, 0 = _index) do
    case Enum.find_index(props, fn p -> p.id == id end) do
      nil -> {:error, :prop_invalid}
      index -> {:ok, index}
    end
  end

  defp get_pdt_write_length(pdt_atom) do
    pdt_length = @pdt_lengths[pdt_atom]
    Map.get(pdt_length, :write_length, Map.get(pdt_length, :length)) * 8
  end

  def encode_list(pid, pdt_atom, list) do
    for(x <- list, do: encode(pid, pdt_atom, x))
    |> :erlang.list_to_bitstring()
  end

  def decode_into_list(pid, pdt_atom, bin) do
    length = get_pdt_write_length(pdt_atom)

    for <<chunk::size(length) <- bin>>,
      do: decode(pid, pdt_atom, <<chunk::size(length)>>)
  end

  def encode(
        prop_id(:device_ctrl),
        _,
        %{
          safe_state: safe_state,
          verify_mode: verify,
          ia_duplication: ia_dup,
          user_stopped: user_stopped
        }
      ),
      do: <<
        0::4,
        bool_to_int(safe_state)::1,
        bool_to_int(verify)::1,
        bool_to_int(ia_dup)::1,
        bool_to_int(user_stopped)::1
      >>

  def encode(prop_id(:prog_mode), _, prog_mode), do: <<0::7, prog_mode::1>>
  def encode(_, :char, char), do: <<char::signed-8>>
  def encode(_, :unsigned_char, unsigned_char), do: <<unsigned_char::8>>
  def encode(_, :int, int), do: <<int::signed-16>>
  def encode(_, :unsigned_int, unsigned_int), do: <<unsigned_int::16>>
  def encode(_, :long, long), do: <<long::signed-32>>
  def encode(_, :unsigned_long, unsigned_long), do: <<unsigned_long::32>>
  def encode(_, :knx_float, _), do: raise("TODO use DPT encode")
  def encode(_, :float, float), do: <<float::float-32>>
  def encode(_, :time, _), do: raise("TODO use DPT encode")
  def encode(_, :date, _), do: raise("TODO use DPT encode")

  def encode(pid, pdt, value) do
    # IO.inspect({pid, pdt, value}, label: :prop_decode_________________)
    # assume unsigned integer for other pdt
    %{length: length} = @pdt_lengths[pdt]
    bit_length = 8 * length
    <<value::size(bit_length)>>
  end

  def decode(
        prop_id(:device_ctrl),
        _,
        <<_::4, safe_state::1, verify::1, ia_dup::1, user_stopped::1>>
      ) do
    %{
      safe_state: safe_state == 1,
      verify_mode: verify == 1,
      ia_duplication: ia_dup == 1,
      user_stopped: user_stopped == 1
    }
  end

  def decode(prop_id(:prog_mode), _, <<_::7, prog_mode::1>>), do: prog_mode
  def decode(_, :ctrl, <<event::8, data::bits>>), do: {event, data}
  def decode(_, :char, <<char::signed-8>>), do: char
  def decode(_, :unsigned_char, <<unsigned_char::8>>), do: unsigned_char
  def decode(_, :int, <<int::signed-16>>), do: int
  def decode(_, :unsigned_int, <<unsigned_int::16>>), do: unsigned_int
  def decode(_, :long, <<long::signed-32>>), do: long
  def decode(_, :unsigned_long, <<unsigned_long::32>>), do: unsigned_long
  def decode(_, :knx_float, _), do: raise("TODO use DPT decoder")
  def decode(_, :float, <<float::float-32>>), do: float
  def decode(_, :time, _), do: raise("TODO use DPT decoder")
  def decode(_, :date, _), do: raise("TODO use DPT decoder")

  def decode(_, pdt, bin) do
    # assume unsigned integer for other pdt
    bit_length = get_pdt_write_length(pdt)

    <<value::size(bit_length)>> = bin
    value
  end
end
