defmodule Knx.Ail.Property do
  # TODO callbacks (prop-fun / Lsm / Rsm)
  # TODO darf nicht ueber ende der liste lesen!

  # TODO 3.7.3 - 4.1
  @pid_device_control 14
  @pid_prog_mode 54

  @pdts %{
    pdt_control: [id: 0x00, length: 1],
    pdt_char: [id: 0x01, length: 1],
    pdt_unsigned_char: [id: 0x02, length: 1],
    pdt_int: [id: 0x03, length: 2],
    pdt_unsigned_int: [id: 0x04, length: 2],
    pdt_knx_float: [id: 0x05, length: 2],
    pdt_date: [id: 0x06, length: 3],
    pdt_time: [id: 0x07, length: 3],
    pdt_long: [id: 0x08, length: 4],
    pdt_unsigned_long: [id: 0x09, length: 4],
    pdt_float: [id: 0x0A, length: 4],
    # pdt_double: [id: 0x0B, length: 8],

    # TODO how to handle this?
    # pdt_char_block: [id: 0x0C, length: 10],
    # pdt_poll_group_setting: [id: 0x0D, length: 3],

    # TODO how to handle this?
    # pdt_short_char_block: [id: 0x0E, length: 5],

    # TODO dpt not implemented
    # pdt_date_time: [id: 0x0F, length: 8],
    # pdt_variable_length: [id: 0x10, length: nil, write_length: nil],
    pdt_generic_01: [id: 0x11, length: 1],
    pdt_generic_02: [id: 0x12, length: 2],
    pdt_generic_03: [id: 0x13, length: 3],
    pdt_generic_04: [id: 0x14, length: 4],
    pdt_generic_05: [id: 0x15, length: 5],
    pdt_generic_06: [id: 0x16, length: 6],
    pdt_generic_07: [id: 0x17, length: 7],
    pdt_generic_08: [id: 0x18, length: 8],
    pdt_generic_09: [id: 0x19, length: 9],
    pdt_generic_10: [id: 0x1A, length: 10],
    pdt_generic_11: [id: 0x1B, length: 11],
    pdt_generic_12: [id: 0x1C, length: 12],
    pdt_generic_13: [id: 0x1D, length: 13],
    pdt_generic_14: [id: 0x1E, length: 14],
    pdt_generic_15: [id: 0x1F, length: 15],
    pdt_generic_16: [id: 0x20, length: 16],
    pdt_generic_17: [id: 0x21, length: 17],
    pdt_generic_18: [id: 0x22, length: 18],
    pdt_generic_19: [id: 0x23, length: 19],
    pdt_generic_20: [id: 0x24, length: 20],
    # pdt_utf8: [id: 0x2F, length: 3],
    pdt_version: [id: 0x30, length: 2],
    pdt_alarm_info: [id: 0x31, length: 6],
    # pdt_binary_information: [id: 0x32, length: 3],
    pdt_bitset8: [id: 0x33, length: 1],
    # pdt_bitset16: [id: 0x34, length: 3],
    # pdt_enum8: [id: 0x35, length: 3],
    pdt_scaling: [id: 0x36, length: 1]
    # pdt_ne_vl: [id: 0x3C, length: 3],
    # pdt_ne_fl: [id: 0x3D, length: 3],
    # pdt_function: [id: 0x3E, length: 3],
    # pdt_escape: [id: 0x3F, length: 3]
  }

  @pids %{
    pid_object_type: [pdt: :pdt_unsigned_int, id: 1],
    # TODO this is an array!!!
    pid_object_name: [pdt: :pdt_unsigned_char, id: 2],
    # PID_SEMAPHOR
    # PID_GROUP_OBJECT_REFERENCE
    pid_load_state_control: [pdt: :pdt_control, id: 5],
    pid_run_state_control: [pdt: :pdt_control, id: 6],
    pid_table_reference: [pdt: :pdt_unsigned_long, id: 7],
    # pid_service_control: [pdt: :pdt__todo__, id: 8],
    # pid_firmware_revision: [pdt: :pdt__todo__, id: 9],
    pid_serial: [pdt: :pdt_generic_06, id: 11],
    pid_manufacturer_id: [pdt: :pdt_unsigned_int, id: 12],
    pid_prog_version: [pdt: :pdt_generic_05, id: 13],
    pid_device_control: [pdt: :pdt_bitset8, id: @pid_device_control],
    pid_order_info: [pdt: :pdt_generic_10, id: 15],
    pid_pei_type: [pdt: :pdt_unsigned_char, id: 16],
    pid_port_configuration: [pdt: :pdt__todo__, id: 17],
    # pid_table: [pdt: :pdt__todo__, id: 23],
    pid_version: [pdt: :pdt_version, id: 25],
    # pid_mcb_table: [pdt: :pdt__todo__, id: 27],
    pid_error_code: [pdt: :pdt_generic_01, id: 28],
    # pid_object_index: [pdt: :pdt__todo__, id: 29],
    # pid_download_counter: [pdt: :pdt__todo__, id: 30],
    pid_routing_count: [pdt: :pdt_unsigned_char, id: 51],
    pid_prog_mode: [pdt: :pdt_bitset8, id: @pid_prog_mode],
    pid_max_apdu_length: [pdt: :pdt_unsigned_int, id: 56],
    pid_subnet_addr: [pdt: :pdt_unsigned_char, id: 57],
    pid_device_addr: [pdt: :pdt_unsigned_char, id: 58],
    # pid_io_list: [pdt: :pdt__todo__, id: 71],
    pid_hardware_type: [pdt: :pdt_generic_06, id: 78],
    # pid_rf_domain_address_cemi_server: [pdt: :pdt__todo__, id: 82],
    pid_device_descriptor: [pdt: :pdt_generic_02, id: 83],
    pid_channel_01_param: [pdt: :pdt_generic_01, id: 101],
    pid_channel_02_param: [pdt: :pdt_generic_01, id: 102],
    pid_channel_03_param: [pdt: :pdt_generic_01, id: 103],
    pid_channel_04_param: [pdt: :pdt_generic_01, id: 104],
    pid_channel_05_param: [pdt: :pdt_generic_01, id: 105],
    pid_channel_06_param: [pdt: :pdt_generic_01, id: 106],
    pid_channel_07_param: [pdt: :pdt_generic_01, id: 107],
    pid_channel_08_param: [pdt: :pdt_generic_01, id: 108],
    pid_channel_09_param: [pdt: :pdt_generic_01, id: 109],
    pid_channel_10_param: [pdt: :pdt_generic_01, id: 110],
    pid_channel_11_param: [pdt: :pdt_generic_01, id: 111],
    pid_channel_12_param: [pdt: :pdt_generic_01, id: 112],
    pid_channel_13_param: [pdt: :pdt_generic_01, id: 113],
    pid_channel_14_param: [pdt: :pdt_generic_01, id: 114],
    pid_channel_15_param: [pdt: :pdt_generic_01, id: 115],
    pid_channel_16_param: [pdt: :pdt_generic_01, id: 116],
    pid_channel_17_param: [pdt: :pdt_generic_01, id: 117],
    pid_channel_18_param: [pdt: :pdt_generic_01, id: 118],
    pid_channel_19_param: [pdt: :pdt_generic_01, id: 119],
    pid_channel_20_param: [pdt: :pdt_generic_01, id: 120],
    pid_channel_21_param: [pdt: :pdt_generic_01, id: 121],
    pid_channel_22_param: [pdt: :pdt_generic_01, id: 122],
    pid_channel_23_param: [pdt: :pdt_generic_01, id: 123],
    pid_channel_24_param: [pdt: :pdt_generic_01, id: 124],
    pid_channel_25_param: [pdt: :pdt_generic_01, id: 125],
    pid_channel_26_param: [pdt: :pdt_generic_01, id: 126],
    pid_channel_27_param: [pdt: :pdt_generic_01, id: 127],
    pid_channel_28_param: [pdt: :pdt_generic_01, id: 128],
    pid_channel_29_param: [pdt: :pdt_generic_01, id: 129],
    pid_channel_30_param: [pdt: :pdt_generic_01, id: 130],
    pid_channel_31_param: [pdt: :pdt_generic_01, id: 131],
    pid_channel_32_param: [pdt: :pdt_generic_01, id: 132]
  }

  defstruct id: nil,
            pdt: nil,
            values: [],
            max: 1,
            write: false,
            r_lvl: 3,
            w_lvl: 0,
            callback: nil

  import Knx.Toolbox

  @me __MODULE__

  def new(id_atom, values, max: max, write: w, r_lvl: r_lvl, w_lvl: w_lvl) do
    [pdt: pdt_atom, id: id] = get_pid(id_atom)

    %@me{
      id: id,
      pdt: pdt_atom,
      values: values,
      max: max,
      write: w,
      r_lvl: r_lvl,
      w_lvl: w_lvl
    }
  end

  def write_prop(props, access_lvl, pid: pid, elems: elems, start: start, data: data) do
    with {:ok, prop_index, _, %@me{pdt: pdt_atom} = prop} <- get_prop(props, pid),
         :ok <- validate(start - 1 + elems <= prop.max, :array_index_out_of_bounds),
         :ok <- authorize(access_lvl, prop.w_lvl),
         values <- decode_into_list(pid, pdt_atom, data),
         {:ok, %@me{} = prop} <- write_prop_(prop, elems, start, values) do
      props = List.replace_at(props, prop_index, prop)
      {:ok, props, prop}
    end
  end

  def read_prop(props, access_lvl, pid: pid, elems: elems, start: start) do
    with {:ok, prop_index, _, %@me{pdt: pdt_atom} = prop} <- get_prop(props, pid),
         :ok <- authorize(access_lvl, prop.r_lvl),
         {:ok, values} <- read_prop_(prop, elems, start),
         data <- encode_list(pid, pdt_atom, values) do
      {:ok, one_based(prop_index), data}
    end
  end

  def get_prop(props, pid, prop_index \\ 0) do
    with {:ok, prop_index} <- get_prop_index(props, pid, prop_index),
         {:ok, %@me{pdt: pdt_atom} = prop} <-
           validate(Enum.fetch(props, prop_index), :prop_invalid),
         [id: pdt, length: _] <- get_pdt(pdt_atom) do
      {:ok, prop_index, pdt, prop}
    end
  end

  # - helper -------------------------------------------------------------------------------------

  def read_prop_value(props, pid_atom) do
    [pdt: _, id: pid] = get_pid(pid_atom)
    {:ok, _, data} = read_prop(props, 0, pid: pid, elems: 1, start: 1)
    data
  end

  def write_prop_value(props, pid_atom, data) do
    [pdt: _, id: pid] = get_pid(pid_atom)
    {:ok, props, _} = write_prop(props, 0, pid: pid, elems: 1, start: 1, data: data)
    props
  end

  def get_table_ref(table_props) do
    read_prop_value(table_props, :pid_device_descriptor)
  end

  # - private -------------------------------------------------------------------------------------

  # [II]
  defp write_prop_(prop, 1 = _elems, 0 = _start, [0] = _data),
    do: {:ok, %{prop | values: []}}

  defp write_prop_(_prop, _elems, 0 = _start, _data),
    do: {:error, :argument_error}

  defp write_prop_(_prop, elems, _start, data) when length(data) != elems,
    do: {:error, :argument_error_data_length}

  defp write_prop_(%{values: values} = prop, _elems, start, data),
    do: {:ok, %{prop | values: insert_list(values, data, start - 1)}}

  defp read_prop_(_, 0 = _elems, 0 = _start), do: {:error, :argument_error}

  defp read_prop_(%{values: values}, _elems, 0 = _start), do: {:ok, [length(values)]}

  defp read_prop_(%{values: values}, elems, start) do
    result = Enum.slice(values, start - 1, elems)

    case length(result) do
      0 -> {:error, :nothing_read}
      _ -> {:ok, result}
    end
  end

  defp get_prop_index(_props, 0 = _id, 0 = _index), do: {:error, :argument_error}
  defp get_prop_index(_props, 0 = _id, index), do: {:ok, zero_based(index)}

  defp get_prop_index(props, id, 0 = _index) do
    case Enum.find_index(props, fn p -> p.id == id end) do
      nil -> {:error, :prop_invalid}
      index -> {:ok, index}
    end
  end

  def get_pid(pid_atom), do: @pids[pid_atom]
  def get_pdt(pdt_atom), do: @pdts[pdt_atom]

  def encode_list(pid, pdt_atom, list) do
    for(x <- list, do: encode(pid, pdt_atom, x))
    |> :erlang.list_to_bitstring()
  end

  def decode_into_list(pid, pdt_atom, bin) do
    length = @pdts[pdt_atom][:length] * 8

    for <<chunk::size(length) <- bin>>,
      do: decode(pid, pdt_atom, <<chunk::size(length)>>)
  end

  def encode(
        @pid_device_control,
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

  def encode(@pid_prog_mode, _, prog_mode), do: <<0::7, prog_mode::1>>
  def encode(_, :pdt_char, char), do: <<char::signed-8>>
  def encode(_, :pdt_unsigned_char, unsigned_char), do: <<unsigned_char::8>>
  def encode(_, :pdt_int, int), do: <<int::signed-16>>
  def encode(_, :pdt_unsigned_int, unsigned_int), do: <<unsigned_int::16>>
  def encode(_, :pdt_long, long), do: <<long::signed-32>>
  def encode(_, :pdt_unsigned_long, unsigned_long), do: <<unsigned_long::32>>
  def encode(_, :pdt_knx_float, _), do: raise("TODO use DPT encode")
  def encode(_, :pdt_float, float), do: <<float::float-32>>
  def encode(_, :pdt_time, _), do: raise("TODO use DPT encode")
  def encode(_, :pdt_date, _), do: raise("TODO use DPT encode")

  def encode(_, pdt, value) do
    # assume unsigned integer for other pdt
    [id: _, length: length] = @pdts[pdt]
    bit_length = 8 * length
    <<value::size(bit_length)>>
  end

  def decode(
        @pid_device_control,
        _,
        <<_::4, safe_state::1, verify::1, ia_dup::1, user_stopped::1>>
      ),
      do: %{
        safe_state: safe_state == 1,
        verify_mode: verify == 1,
        ia_duplication: ia_dup == 1,
        user_stopped: user_stopped == 1
      }

  def decode(@pid_prog_mode, _, <<_::7, prog_mode::1>>), do: prog_mode
  def decode(_, :pdt_char, <<char::signed-8>>), do: char
  def decode(_, :pdt_unsigned_char, <<unsigned_char::8>>), do: unsigned_char
  def decode(_, :pdt_int, <<int::signed-16>>), do: int
  def decode(_, :pdt_unsigned_int, <<unsigned_int::16>>), do: unsigned_int
  def decode(_, :pdt_long, <<long::signed-32>>), do: long
  def decode(_, :pdt_unsigned_long, <<unsigned_long::32>>), do: unsigned_long
  def decode(_, :pdt_knx_float, _), do: raise("TODO use DPT decoder")
  def decode(_, :pdt_float, <<float::float-32>>), do: float
  def decode(_, :pdt_time, _), do: raise("TODO use DPT decoder")
  def decode(_, :pdt_date, _), do: raise("TODO use DPT decoder")

  def decode(_, pdt, bin) do
    # assume unsigned integer for other pdt
    [id: _, length: length] = @pdts[pdt]
    bit_length = 8 * length
    <<value::size(bit_length)>> = bin
    value
  end
end
