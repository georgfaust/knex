defmodule AuthTest do
  use ExUnit.Case

  alias Knx.Auth

  @some_key 1
  @default_key 0
  @delete_key 0xFF_FF_FF_FF
  @anonomymous_key 0xFF_FF_FF_FF
  @unauthorized 0xFF
  @default_level 3

  @key_0 0xAA
  @key_1 0xBB
  @key_2 0xCC
  @key_3 0xDD

  test "auth" do
    assert %Auth{access_lvl: @default_level} = Auth.auth(%Auth{}, @anonomymous_key)
    assert {%Auth{}, @unauthorized} = Auth.key_write(%Auth{}, @some_key, 0)

    assert %Auth{access_lvl: 3} = Auth.auth(%Auth{}, @delete_key)

    assert %Auth{access_lvl: 0} = auth = Auth.auth(%Auth{}, @default_key)

    assert {%Auth{} = auth, 0} = Auth.key_write(auth, @key_0, 0)
    assert {%Auth{} = auth, 1} = Auth.key_write(auth, @key_1, 1)
    assert {%Auth{} = auth, 2} = Auth.key_write(auth, @key_2, 2)
    assert {%Auth{} = auth, 3} = Auth.key_write(auth, @key_3, 3)

    assert %Auth{access_lvl: 0} = auth = Auth.auth(auth, @key_0)
    assert {%Auth{}, 0} = Auth.key_write(auth, @some_key, 0)
    assert {%Auth{}, 1} = Auth.key_write(auth, @some_key, 1)
    assert {%Auth{}, 2} = Auth.key_write(auth, @some_key, 2)
    assert {%Auth{}, 3} = Auth.key_write(auth, @some_key, 3)
    assert %Auth{access_lvl: 1} = auth = Auth.auth(auth, @key_1)
    assert {%Auth{}, @unauthorized} = Auth.key_write(auth, @some_key, 0)
    assert {%Auth{}, 1} = Auth.key_write(auth, @some_key, 1)
    assert {%Auth{}, 2} = Auth.key_write(auth, @some_key, 2)
    assert {%Auth{}, 3} = Auth.key_write(auth, @some_key, 3)
    assert %Auth{access_lvl: 2} = auth = Auth.auth(auth, @key_2)
    assert {%Auth{}, @unauthorized} = Auth.key_write(auth, @some_key, 0)
    assert {%Auth{}, @unauthorized} = Auth.key_write(auth, @some_key, 1)
    assert {%Auth{}, 2} = Auth.key_write(auth, @some_key, 2)
    assert {%Auth{}, 3} = Auth.key_write(auth, @some_key, 3)
    assert %Auth{access_lvl: 3} = auth = Auth.auth(auth, @key_3)
    assert {%Auth{}, @unauthorized} = Auth.key_write(auth, @some_key, 0)
    assert {%Auth{}, @unauthorized} = Auth.key_write(auth, @some_key, 1)
    assert {%Auth{}, @unauthorized} = Auth.key_write(auth, @some_key, 2)
    assert {%Auth{}, 3} = Auth.key_write(auth, @some_key, 3)

    assert %Auth{access_lvl: 0} = auth = Auth.auth(auth, @key_0)
    assert %Auth{access_lvl: 3} = Auth.de_auth(auth)
  end
end
