defmodule Knx.Ail.IoServerTest do
  use ExUnit.Case

  alias Knx.State, as: S
  alias Knx.Frame, as: F
  alias Knx.Ail.IoServer
  alias Knx.Ail.Property, as: P

  @serial 0x112233445566
  @desc 0x07B0

  @new_subnet_addr 0x08
  @new_device_addr 0x15
  @new_ind_addr <<@new_subnet_addr, @new_device_addr>>
  @other_serial 0x1122334455FF

  @state_1 %S{
    objects: %{0 => Helper.get_device_props(1)}
  }

  @state_2 %S{
    objects: %{0 => Helper.get_device_props(0)}
  }

  @pid_manufacturer_id 12
  @p_idx_manufacturer_id 4
  @pdt_manufacturer_id 4

  # a_prop_desc_resp_pdu(
  #   [o_idx, pid, p_idx, write, pdt, max, r_lvl, w_lvl])
  @manu_prop_desc_resp [
    0,
    @pid_manufacturer_id,
    @p_idx_manufacturer_id,
    0,
    @pdt_manufacturer_id,
    1,
    3,
    0
  ]

  @invalid_pid 4711
  @invalid_idx 99
  @error_pid_prop_desc_resp [0, @invalid_pid, 0, 0, 0, 0, 0, 0]
  @error_idx_prop_desc_resp [0, 0, @invalid_idx, 0, 0, 0, 0, 0]

  # a_prop_resp_pdu(
  #   [o_idx, pid, elems, start, data])
  @manu_prop_resp [0, @pid_manufacturer_id, 1, 1, <<0xAFFE::16>>]
  @manu_prop_write_resp [0, @pid_manufacturer_id, 1, 1, <<0xBEEF::16>>]

  test "silently drops unknown requests, sets state.objects to nil" do
    assert {[], %S{objects: nil}} = IoServer.handle({:io, :req, %F{}}, @state_1)
  end

  describe "responds to prop_desc_read" do
    test "(existing pid) with a prop_desc_resp" do
      assert {[{:al, :req, %F{apci: :prop_desc_resp, apdu: @manu_prop_desc_resp}}],
              %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req,
                  %F{
                    apci: :prop_desc_read,
                    apdu: [0, @pid_manufacturer_id, 0]
                  }},
                 @state_1
               )
    end

    test "(existing index) with a prop_desc_resp" do
      assert {[{:al, :req, %F{apci: :prop_desc_resp, apdu: @manu_prop_desc_resp}}],
              %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req,
                  %F{
                    apci: :prop_desc_read,
                    apdu: [0, 0, @p_idx_manufacturer_id]
                  }},
                 @state_1
               )
    end

    test "(invalid pid) with an error-prop_desc_resp" do
      assert {[{:al, :req, %F{apci: :prop_desc_resp, apdu: @error_pid_prop_desc_resp}}],
              %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req,
                  %F{
                    apci: :prop_desc_read,
                    apdu: [0, @invalid_pid, 0]
                  }},
                 @state_1
               )
    end

    test "(invalid index) with an error-prop_desc_resp" do
      assert {[{:al, :req, %F{apci: :prop_desc_resp, apdu: @error_idx_prop_desc_resp}}],
              %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req,
                  %F{
                    apci: :prop_desc_read,
                    apdu: [0, 0, @invalid_idx]
                  }},
                 @state_1
               )
    end
  end

  describe "responds to prop_read" do
    test "(valid pid) with a prop_resp" do
      assert {[{:al, :req, %F{apci: :prop_resp, apdu: @manu_prop_resp}}], %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req,
                  %F{
                    apci: :prop_read,
                    #     [o_idx, pid, elems, start]
                    apdu: [0, @pid_manufacturer_id, 1, 1]
                  }},
                 @state_1
               )
    end

    test "(invalid pid) with ???" do
      # TODO verhalten unklar!
      # assert {[{:al, :req, %F{apci: :prop_resp, apdu: @error_prop_resp}}], %S{}} =
      #          IoServer.handle(
      #            {:io, :req,
      #             %F{
      #               apci: :prop_read,
      #               apdu: [0, @invalid_pid, 1, 1]
      #             }},
      #            @state_1
      #          )
    end
  end

  describe "responds to prop_write" do
    test "(valid pid) with a prop_resp" do
      assert {[{:al, :req, %F{apci: :prop_resp, apdu: @manu_prop_write_resp}}],
              %S{objects: %{0 => props}}} =
               IoServer.handle(
                 {:io, :req,
                  %F{
                    apci: :prop_write,
                    #     [o_idx, pid, elems, start, data]
                    apdu: [0, @pid_manufacturer_id, 1, 1, <<0xBEEF::16>>]
                  }},
                 @state_1
               )

      assert props
      assert <<0xBEEF::16>> == P.read_prop_value(props, :pid_manufacturer_id)
    end

    test "(invalid pid) ???" do
      # TODO
    end
  end

  describe "on ind_addr_write" do
    test "when prog mode active: changes the addr properties" do
      assert {[], %S{objects: %{0 => props}}} =
               IoServer.handle(
                 {:io, :req, %F{apci: :ind_addr_write, apdu: [@new_ind_addr]}},
                 @state_1
               )

      assert props
      assert <<@new_subnet_addr>> == P.read_prop_value(props, :pid_subnet_addr)
      assert <<@new_device_addr>> == P.read_prop_value(props, :pid_device_addr)
    end

    test "when prog mode inactive, addr properties are not changed" do
      assert {[], %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req, %F{apci: :ind_addr_write, apdu: [@new_ind_addr]}},
                 @state_2
               )
    end
  end

  describe "handles an ind_addr_read" do
    test "when prog mode active by responding with an ind_addr_resp" do
      assert {[{:al, :req, %F{apci: :ind_addr_resp}}], %S{objects: nil}} =
               IoServer.handle({:io, :req, %F{apci: :ind_addr_read}}, @state_1)
    end

    test "when prog mode inactive, nothing happens" do
      assert {[], %S{objects: nil}} =
               IoServer.handle({:io, :req, %F{apci: :ind_addr_read}}, @state_2)
    end
  end

  describe "handles an ind_addr_serial_write" do
    test "when serial matches by changing the addr properties" do
      assert {[], %S{objects: %{0 => props}}} =
               IoServer.handle(
                 {:io, :req, %F{apci: :ind_addr_serial_write, apdu: [@serial, @new_ind_addr]}},
                 @state_1
               )

      assert props
      assert <<@new_subnet_addr>> == P.read_prop_value(props, :pid_subnet_addr)
      assert <<@new_device_addr>> == P.read_prop_value(props, :pid_device_addr)
    end

    test "when serial does not match, addr properties are not changed" do
      assert {[], %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req,
                  %F{apci: :ind_addr_serial_write, apdu: [@other_serial, @new_ind_addr]}},
                 @state_1
               )
    end
  end

  describe "handles an ind_addr_serial_read" do
    test "when serial matches by responding with an ind_addr_serial_resp" do
      assert {[{:al, :req, %F{apci: :ind_addr_serial_resp, apdu: [@serial, 0]}}],
              %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req, %F{apci: :ind_addr_serial_read, apdu: [@serial]}},
                 @state_1
               )
    end

    test "when serial does not match, nothing happens" do
      assert {[], %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req, %F{apci: :ind_addr_serial_read, apdu: [@other_serial]}},
                 @state_1
               )
    end
  end

  describe "handles an device_desc_read" do
    test "with desc_type=0 by responding with an " do
      assert {[{:al, :req, %F{apci: :device_desc_resp, apdu: [0, <<@desc::16>>]}}],
              %S{objects: nil}} =
               IoServer.handle(
                 {:io, :req, %F{apci: :device_desc_read, apdu: [0]}},
                 @state_1
               )
    end
  end
end
