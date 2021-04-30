defmodule Knx.TimerTest do
  use ExUnit.Case
  alias Knx.Timer

  # TODO crasht manchmal ...

  setup do
    pid = start_supervised!({Timer, {self(), %{{:target, :foo} => 10}}})
    %{pid: pid}
  end

  test "start", %{pid: pid} do
    Timer.handle(pid, {:timer, :start, {:target, :foo}}, nil)
    refute_receive {:target, :timeout, :foo}, 9
    assert_receive {:target, :timeout, :foo}, 11
  end

  test "restart", %{pid: pid} do
    Timer.handle(pid, {:timer, :start, {:target, :foo}}, nil)
    :timer.sleep(5)
    Timer.handle(pid, {:timer, :restart, {:target, :foo}}, nil)
    refute_receive {:target, :timeout, :foo}, 9
    assert_receive {:target, :timeout, :foo}, 11
  end

  test "stop", %{pid: pid} do
    Timer.handle(pid, {:timer, :start, {:target, :foo}}, nil)
    :timer.sleep(5)
    Timer.handle(pid, {:timer, :stop, {:target, :foo}}, nil)
    refute_receive {:target, :timeout, :foo}, 11
  end
end
