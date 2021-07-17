defmodule Knx.Ail.GoServerTest do
  use ExUnit.Case

  alias Knx.Ail.GoServer, as: GOS
  alias Knx.Ail.GroupObject, as: GO
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @assoc_tab Helper.get_assoc_tab()
  @go_tab Helper.get_go_tab()
  @go_values Helper.get_go_values()
  @cache %{
    go_tab: @go_tab,
    assoc_tab: @assoc_tab,
    go_values: @go_values
  }

  setup do
    Cache.start_link(@cache)
    :ok
  end

  # TODO encode / decode

  test "get first" do
    assert {:ok, {1, %GO{asap: 1}}} = GOS.get_first(:any, asap: 1)
    assert {:ok, {1, %GO{asap: 1}}} = GOS.get_first(:transmits, asap: 1)
    assert {:ok, {1, %GO{asap: 1}}} = GOS.get_first(:transmits, tsap: 1)
    assert :error = GOS.get_first(:transmits, tsap: 99)
  end

  test "group_read.req" do
    assert {%S{}, [{:al, :req, %{apci: :group_read, tsap: 1}}]} =
             GOS.handle(
               {:go, :req, %F{apci: :group_read, asap: 1, tsap: nil}},
               %S{}
             )

    assert {%S{}, []} =
             GOS.handle(
               {:go, :req, %F{apci: :group_read, asap: 3, tsap: nil}},
               %S{}
             )
  end

  test "group_write.req" do
    assert {%S{} = state,
            [
              {:app, :go_value, {5, <<1>>}},
              {:al, :req, %F{apci: :group_write, tsap: 5}}
            ]} =
             GOS.handle(
               {:go, :req, %F{apci: :group_write, asap: 5, tsap: nil, data: <<1>>}},
               %S{}
             )

    # this will be deferred
    assert {
             %S{go_server: %{deferred: [{:al, :req, %F{}}]}} = state,
             [{:app, :go_value, {5, <<1>>}}]
           } =
             GOS.handle(
               {:go, :req, %F{apci: :group_write, asap: 5, tsap: nil, data: <<1>>}},
               state
             )

    # conf recalls deferred impulse
    assert {
             %S{go_server: %{deferred: []}} = state,
             [{:al, :req, %F{apci: :group_write, data: <<1>>, asap: 5, tsap: 5}}]
           } = GOS.handle({:go, :conf, %F{}}, state)

    assert {%S{}, []} =
             GOS.handle(
               {:go, :req, %F{apci: :group_write, asap: 2, tsap: nil, data: <<1>>}},
               state
             )
  end

  test "group_read.ind" do
    # TODO resp_tsap != tsap, dafuere andere assoc table
    assert {
             %S{},
             [
               {:app, :go_value, {3, [<<0::6>>]}},
               {:al, :req, %F{apci: :group_resp, tsap: 3}}
             ]
           } =
             GOS.handle(
               {:go, :ind, %F{apci: :group_read, asap: nil, tsap: 3}},
               %S{}
             )
  end

  test "group_write.ind" do
    # TODO testen mit mehr assocs auf einem tsap
    assert {
             %S{},
             [{:app, :go_value, {2, <<2>>}}]
           } =
             GOS.handle(
               {:go, :ind, %F{apci: :group_write, asap: nil, tsap: 2, data: <<2>>}},
               %S{}
             )

    assert {%S{}, []} =
             GOS.handle(
               {:go, :ind, %F{apci: :group_write, asap: nil, tsap: 99, data: <<2>>}},
               %S{}
             )
  end

  test "group_resp.ind" do
    # TODO testen mit mehr assocs auf einem tsap
    assert {%S{}, [{:app, :go_value, {4, <<2>>}}]} =
             GOS.handle(
               {:go, :ind, %F{apci: :group_resp, asap: nil, tsap: 4, data: <<2>>}},
               %S{}
             )

    assert {%S{}, []} =
             GOS.handle(
               {:go, :ind, %F{apci: :group_resp, asap: nil, tsap: 99, data: <<2>>}},
               %S{}
             )
  end
end
