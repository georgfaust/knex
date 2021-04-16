defmodule AuthTest do
  use ExUnit.Case

  alias Knx.Auth
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @some_key 1
  @default_key 0
  @delete_key 0xFF_FF_FF_FF
  @anonymous_key 0xFF_FF_FF_FF
  @invalid_key -1
  @unauthorized 0xFF
  @default_level 3

  @key_0 0xAA
  @key_1 0xBB
  @key_2 0xCC
  @key_3 0xDD

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

  test "auth_request.ind and key_write.ind" do
    # without authorization, level 3 is the default access level for key_write
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [@default_level]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [3, @some_key]}},
        %S{auth: %Auth{}}
      )

    # without authorization, key_write accessing higher levels results
    #   in key_response with @unauthorized as data
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [@unauthorized]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [0, @some_key]}},
        %S{auth: %Auth{}}
      )

    # by default, default level has key @anonymous_key
    assert {
      %S{auth: %Auth{access_lvl: @default_level}},
      [{:al, :req, %F{apci: :auth_response, data: [@default_level]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :auth_request, data: [@anonymous_key]}},
        %S{auth: %Auth{}}
      )

    # authorization with invalid key results in default level access
    assert {
      %S{auth: %Auth{access_lvl: @default_level}},
      [{:al, :req, %F{apci: :auth_response, data: [@default_level]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :auth_request, data: [@some_key]}},
        %S{auth: %Auth{}}
      )

    # authorization for access level 0 allows key_write to set keys for all access levels
    assert {
      %S{auth: %Auth{access_lvl: 0}},
      [{:al, :req, %F{apci: :auth_response, data: [0]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :auth_request, data: [@default_key]}},
        %S{auth: %Auth{}}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [0]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [0, @key_0]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [1]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [1, @key_1]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [2]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [2, @key_2]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [3]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [3, @key_3]}},
        %S{auth: auth}
      )

    # authorization with key for access level 0
    assert {
      %S{auth: %Auth{access_lvl: 0}},
      [{:al, :req, %F{apci: :auth_response, data: [0]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :auth_request, data: [@key_0]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [0]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [0, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [1]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [1, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [2]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [2, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [3]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [3, @some_key]}},
        %S{auth: auth}
      )

    # authorization with key for access level 1
    assert {
      %S{auth: %Auth{access_lvl: 1}},
        [{:al, :req, %F{apci: :auth_response, data: [1]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :auth_request, data: [@key_1]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [@unauthorized]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [0, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [1]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [1, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [2]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [2, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [3]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [3, @some_key]}},
        %S{auth: auth}
      )

    # authorization with key for access level 2
    assert {
      %S{auth: %Auth{access_lvl: 2}},
      [{:al, :req, %F{apci: :auth_response, data: [2]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :auth_request, data: [@key_2]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [@unauthorized]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [0, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [@unauthorized]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [1, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [2]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [2, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [3]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [3, @some_key]}},
        %S{auth: auth}
      )

    # authorization with key for access level 3
    assert {
      %S{auth: %Auth{access_lvl: 3}},
      [{:al, :req, %F{apci: :auth_response, data: [3]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :auth_request, data: [@key_3]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [@unauthorized]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [0, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [@unauthorized]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [1, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [@unauthorized]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [2, @some_key]}},
        %S{auth: auth}
      )
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [3]}}]
    } =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [3, @some_key]}},
        %S{auth: auth}
      )

    # key_write using @delete_key as key sets access level key to @invalid_key
    assert {
      %S{auth: %Auth{}},
      [{:al, :req, %F{apci: :key_response, data: [3]}}]
    } =
      {%S{auth: %Auth{} = auth}, _} =
      Auth.handle(
        {:auth, :ind, %F{apci: :key_write, data: [3, @delete_key]}},
        %S{auth: %Auth{}}
      )
    assert {
      %S{auth: %Auth{access_lvl: 3}},
      [{:al, :req, %F{apci: :auth_response, data: [3]}}]} =
      Auth.handle(
        {:auth, :ind, %F{apci: :auth_request, data: [@invalid_key]}},
        %S{auth: auth}
    )
  end
end
