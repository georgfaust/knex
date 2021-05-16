defmodule Knx.Knxnetip.IPTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Knxnetip.CEMIFrame
  alias Knx.Knxnetip.IpInterface, as: Ip

  require Knx.Defs
  import Knx.Defs

  ## Tunneling Req:
  @ip_src {0xC0A8_B23E, 0x0E75}
  # @ip_dest {0xC0A8_B215, 0xF3A2}
  @tunneling_req_group_value_write <<0x0610_0420_0015_049F_0000_2900_BCE0_2102_0001_0100_81::unit(8)-size(21)>>
  # cEMI Frame -----------------------------------------------------------------
  @cemi_message_code_l_data_ind 0x29
  # @additional_info 0x00
  # @frame_type 0x10
  @src 0x2102
  @dest 0x0001
  @prio 3
  @hops 6
  @len 1
  @data <<0x0081::unit(8)-size(2)>>
  @eff 0
  @confirm 0

  ## Tunneling Ack:
  # KNXnet/IP Header -----------------------------------------------------------
  @header_size 0x06
  @protocol_version 0x10
  @service_type_id_tunneling_ack 0x0421
  @total_length 0x000a
  # Connection Header ----------------------------------------------------------
  @structure_length_connection_header 0x04
  @channel_id 0x9F
  @sequence_counter 0x00
  @status 0x00

  test "tunneling request, group value write" do
    assert [
             {:ethernet, :transmit, @ip_src,
              <<
                @header_size::8,
                @protocol_version::8,
                @service_type_id_tunneling_ack::16,
                @total_length::16,
                @structure_length_connection_header::8,
                @channel_id::8,
                @sequence_counter::8,
                @status::8
              >>},

             {:dl, :req,
             %CEMIFrame{
              message_code: @cemi_message_code_l_data_ind,
              src: @src,
              dest: @dest,
              addr_t: addr_t(:grp),
              prio: @prio,
              hops: @hops,
              len: @len,
              data: @data,
              eff: @eff,
              confirm: @confirm
             }
            }
           ] =
             Ip.handle(
               {
                 :ip,
                 :from_ip,
                 @ip_src,
                 @tunneling_req_group_value_write
               },
               %S{}
             )
  end
end
