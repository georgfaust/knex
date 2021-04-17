defmodule Knx.Ail.Device do
  alias Knx.Ail.Property

  # TODO Auth --- unklar, aber gehe davon aus, dass jeweils die Rechte auf dem IO ausschlaggebend sind
  #   auch wenn nicht direkt uber data-primitives zugegriffen wird

  def get_desc(props),
    do: Property.read_prop_value(props, :pid_device_descriptor)

  def set_address(props, <<subnet_addr::8, device_addr::8>>) do
    props
    |> Property.write_prop_value(:pid_subnet_addr, <<subnet_addr>>)
    |> Property.write_prop_value(:pid_device_addr, <<device_addr>>)
  end

  def prog_mode?(props),
    do: <<1>> == Property.read_prop_value(props, :pid_prog_mode)

  def serial_matches?(props, other_serial) do
    <<other_serial::48>> == Property.read_prop_value(props, :pid_serial)
  end

  def get_max_apdu_length(props),
    do: Property.read_prop_value(props, :pid_max_apdu_length)

  def verify?(props) do
    [%{verify_mode: verify}] = Property.read_prop_value_decoded(props, :pid_device_control)
    verify
  end
end
