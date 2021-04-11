defmodule Knx.Ail.GoServerTest do
  use ExUnit.Case

  alias Knx.Ail.GoServer, as: GOS
  alias Knx.Ail.GroupObject, as: GO
  alias Knx.Frame, as: F

  @assoc_tab [
    {1, 1},
    {2, 2},
    {3, 3},
    {4, 4},
    {5, 5},
    {6, 6}
  ]

  @go_tab %{
    1 => %GO{asap: 1, transmits: true},
    2 => %GO{asap: 2, writable: true},
    3 => %GO{asap: 3, readable: true},
    4 => %GO{asap: 4, updatable: true},
    5 => %GO{asap: 5, transmits: true, readable: true},
    6 => %GO{asap: 6, transmits: true, readable: true, updatable: true}
  }

  # TODO encode / decode

  test "get first" do
    assert {:ok, {1, %GO{asap: 1}}} = GOS.get_first(@assoc_tab, @go_tab, :any, asap: 1)
    assert {:ok, {1, %GO{asap: 1}}} = GOS.get_first(@assoc_tab, @go_tab, :transmits, asap: 1)
    assert {:ok, {1, %GO{asap: 1}}} = GOS.get_first(@assoc_tab, @go_tab, :transmits, tsap: 1)
    assert :error = GOS.get_first(@assoc_tab, @go_tab, :transmits, tsap: 99)
  end

  test "group_read.req" do
    assert {%GOS{impulses: []}, [{:al, :req, %{apci: :group_read, tsap: 1}}]} =
             GOS.handle(
               {:go, :req, %F{apci: :group_read, asap: 1, tsap: nil}},
               {@assoc_tab, @go_tab, %GOS{}}
             )

    assert {%GOS{impulses: []}, []} =
             GOS.handle(
               {:go, :req, %F{apci: :group_read, asap: 3, tsap: nil}},
               {@assoc_tab, @go_tab, %GOS{}}
             )
  end

  test "group_write.req" do
    assert {%GOS{impulses: [], deferred: []} = state,
            [
              {:user, :go_value, {5, <<1>>}},
              {:al, :req, %F{apci: :group_write, tsap: 5}}
            ]} =
             GOS.handle(
               {:go, :req, %F{apci: :group_write, asap: 5, tsap: nil, data: <<1>>}},
               {@assoc_tab, @go_tab, %GOS{}}
             )

    # this will be deferred
    assert {
             %GOS{impulses: [], deferred: [{:al, :req, %F{}}]} = state,
             [{:user, :go_value, {5, <<1>>}}]
           } =
             GOS.handle(
               {:go, :req, %F{apci: :group_write, asap: 5, tsap: nil, data: <<1>>}},
               {@assoc_tab, @go_tab, state}
             )

    # conf recalls deferred impulse
    assert {
             %GOS{impulses: [], deferred: []} = state,
             [{:al, :req, %F{apci: :group_write, data: <<1>>, asap: 5, tsap: 5}}]
           } = GOS.handle({:go, :conf, %F{}}, {@assoc_tab, @go_tab, state})

    assert {%GOS{}, []} =
             GOS.handle(
               {:go, :req, %F{apci: :group_write, asap: 2, tsap: nil, data: <<1>>}},
               {@assoc_tab, @go_tab, state}
             )
  end

  test "group_read.ind" do
    # TODO resp_tsap != tsap, dafuere andere assoc table
    assert {
             %GOS{},
             [
               {:user, :go_value, {3, 0}},
               {:al, :req, %F{apci: :group_resp, tsap: 3}}
             ]
           } =
             GOS.handle(
               {:go, :ind, %F{apci: :group_read, asap: nil, tsap: 3}},
               {@assoc_tab, @go_tab, %GOS{}}
             )
  end

  test "group_write.ind" do
    # TODO testen mit mehr assocs auf einem tsap
    assert {
             %GOS{},
             [{:user, :go_value, {2, <<2>>}}]
           } =
             GOS.handle(
               {:go, :ind, %F{apci: :group_write, asap: nil, tsap: 2, data: <<2>>}},
               {@assoc_tab, @go_tab, %GOS{}}
             )

    assert {%GOS{}, []} =
             GOS.handle(
               {:go, :ind, %F{apci: :group_write, asap: nil, tsap: 99, data: <<2>>}},
               {@assoc_tab, @go_tab, %GOS{}}
             )
  end

  test "group_resp.ind" do
    # TODO testen mit mehr assocs auf einem tsap
    assert {%GOS{}, [{:user, :go_value, {4, <<2>>}}]} =
             GOS.handle(
               {:go, :ind, %F{apci: :group_resp, asap: nil, tsap: 4, data: <<2>>}},
               {@assoc_tab, @go_tab, %GOS{}}
             )

    assert {%GOS{}, []} =
             GOS.handle(
               {:go, :ind, %F{apci: :group_resp, asap: nil, tsap: 99, data: <<2>>}},
               {@assoc_tab, @go_tab, %GOS{}}
             )
  end
end
