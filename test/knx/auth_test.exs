defmodule AuthTest do
  use ExUnit.Case

  alias Knx.Auth
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @some_key 1
  @default_key 0
  @delete_key 0xFF_FF_FF_FF
  @anon_key 0xFF_FF_FF_FF
  @invalid_key -1
  @unauthorized 0xFF
  @default_lvl 3

  @key_0 0xAA
  @key_1 0xBB
  @key_2 0xCC
  @key_3 0xDD

  def key_write(req_lvl, req_key, res_lvl, auth \\ %Auth{}) do
    assert {
             %S{auth: %Auth{} = new_auth},
             [{:al, :req, %F{apci: :key_response, data: [^res_lvl]}}]
           } =
             Auth.handle(
               {:auth, :ind, %F{apci: :key_write, data: [req_lvl, req_key]}},
               %S{auth: auth}
             )

    new_auth
  end

  def auth(req_key, res_lvl, auth \\ %Auth{}) do
    assert {
             %S{auth: new_auth},
             [{:al, :req, %F{apci: :auth_response, data: [^res_lvl]}}]
           } =
             Auth.handle(
               {:auth, :ind, %F{apci: :auth_request, data: [req_key]}},
               %S{auth: auth}
             )

    new_auth
  end

  test "auth_request.req" do
    assert [{:al, :req, %F{apci: :auth_request}}] =
             Auth.handle(
               {:auth, :req, %F{apci: :auth_request}},
               %S{}
             )
  end

  test "key_write.req" do
    assert [{:al, :req, %F{apci: :key_write}}] =
             Auth.handle(
               {:auth, :req, %F{apci: :key_write}},
               %S{}
             )
  end

  describe "auth_request.ind and key_write.ind" do
    test "any key can write a key to lvl 3" do
      assert %Auth{keys: [0, 0, 0, @some_key]} = key_write(3, @some_key, @default_lvl)
    end

    test "key write to higher lvls requires authorization" do
      assert %Auth{} = key_write(0, @some_key, @unauthorized)
    end

    test "by default, default lvl has key @anon_key" do
      assert %Auth{access_lvl: @default_lvl} =
               auth(@anon_key, @default_lvl, %Auth{access_lvl: 99})
    end

    test "authorization with invalid key results in default lvl access" do
      assert %Auth{access_lvl: @default_lvl} =
               auth(@anon_key, @default_lvl, %Auth{access_lvl: 99})
    end

    test "authorization for access lvl 0 allows key_write to set keys for all access lvls" do
      assert %Auth{access_lvl: 0} = auth_ = auth(@default_key, 0, %Auth{access_lvl: 99})

      assert %Auth{keys: [@key_0, _, _, _]} = key_write(0, @key_0, 0, auth_)
      assert %Auth{keys: [_, @key_1, _, _]} = key_write(1, @key_1, 1, auth_)
      assert %Auth{keys: [_, _, @key_2, _]} = key_write(2, @key_2, 2, auth_)
      assert %Auth{keys: [_, _, _, @key_3]} = key_write(3, @key_3, 3, auth_)
    end

    test "authorization with key for access lvl 0" do
      assert %Auth{access_lvl: 0} = auth_ = auth(@key_0, 0, %Auth{keys: [@key_0, 0, 0, 0]})

      assert %Auth{keys: [@some_key, _, _, _]} = key_write(0, @some_key, 0, auth_)
      assert %Auth{keys: [_, @some_key, _, _]} = key_write(1, @some_key, 1, auth_)
      assert %Auth{keys: [_, _, @some_key, _]} = key_write(2, @some_key, 2, auth_)
      assert %Auth{keys: [_, _, _, @some_key]} = key_write(3, @some_key, 3, auth_)
    end

    test "authorization with key for access lvl 1" do
      assert %Auth{access_lvl: 1} = auth_ = auth(@key_1, 1, %Auth{keys: [0, @key_1, 0, 0]})

      assert %Auth{} = key_write(0, @some_key, @unauthorized, auth_)
      assert %Auth{keys: [_, @some_key, _, _]} = key_write(1, @some_key, 1, auth_)
      assert %Auth{keys: [_, _, @some_key, _]} = key_write(2, @some_key, 2, auth_)
      assert %Auth{keys: [_, _, _, @some_key]} = key_write(3, @some_key, 3, auth_)
    end

    test "authorization with key for access lvl 2" do
      assert %Auth{access_lvl: 2} = auth_ = auth(@key_2, 2, %Auth{keys: [0, 0, @key_2, 0]})

      assert %Auth{} = key_write(0, @some_key, @unauthorized, auth_)
      assert %Auth{} = key_write(1, @some_key, @unauthorized, auth_)
      assert %Auth{keys: [_, _, @some_key, _]} = key_write(2, @some_key, 2, auth_)
      assert %Auth{keys: [_, _, _, @some_key]} = key_write(3, @some_key, 3, auth_)
    end

    test "authorization with key for access lvl 3" do
      assert %Auth{access_lvl: 3} = auth_ = auth(@key_3, 3, %Auth{keys: [0, 0, 0, @key_3]})

      assert %Auth{} = key_write(0, @some_key, @unauthorized, auth_)
      assert %Auth{} = key_write(1, @some_key, @unauthorized, auth_)
      assert %Auth{} = key_write(2, @some_key, @unauthorized, auth_)
      assert %Auth{keys: [_, _, _, @some_key]} = key_write(3, @some_key, 3, auth_)
    end

    test "key_write using @delete_key as key sets access lvl key to @invalid_key" do
      assert %Auth{keys: [_, _, _, @invalid_key]} = key_write(3, @delete_key, 3, %Auth{})
    end
  end
end
