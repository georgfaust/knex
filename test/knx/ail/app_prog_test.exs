defmodule Knx.Ail.AppProgTest do
  use ExUnit.Case
  import Knx.Ail.AppProg
  alias Knx.Ail.Property, as: P
  import Knx.Defs
  require Knx.Defs


  @ref_app_prog 4
  @app_prog_props Knx.Ail.AppProg.get_props(@ref_app_prog, 1)
  @mem <<0::unit(8)-size(4), 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0::size(800)>>
  @app_prog <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0::unit(8)-size(90)>>

  setup do
    Cache.start_link(%{
      objects: [app_prog: @app_prog_props],
      mem: @mem
    })

    load()

    :ok
  end

  test "app prog" do
    assert {:ok, [{:control, :restart, :app}]} == load()
    assert @app_prog = Cache.get(:app_prog)
  end

  test "restart app from lsm" do

    assert {:ok, props,_, _} =
      P.write_prop(1, @app_prog_props, 0,
        pid: prop_id(:load_state_ctrl),
        elems: 1,
        start: 1,
        data: <<load_event(:start_loading)::8, 0::unit(8)-9>>
      )

    assert {:ok, _, _, [{:control, :restart, :app}]} =
      P.write_prop(4, props, 0,
        pid: prop_id(:load_state_ctrl),
        elems: 1,
        start: 1,
        data: <<load_event(:load_completed)::8, 0::unit(8)-9>>
      )
  end
end
