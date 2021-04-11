defmodule PureLoggerTest do
  use ExUnit.Case

  test "mac" do
    require PureLogger

    assert [{:logger, :error, {4711, %{file: _, line: _}}}] = PureLogger.error(4711)
    assert [{:logger, :error, {'test', %{file: _, line: _}}}] = PureLogger.error('test')
    assert [{:logger, :error, {"test", %{file: _, line: _}}}] = PureLogger.error("test")
    assert [{:logger, :error, {[1, 2, 3], %{file: _, line: _}}}] = PureLogger.error([1, 2, 3])
    assert [{:logger, :error, {[a: 1, b: 2], %{file: _, line: _}}}] = PureLogger.error(a: 1, b: 2)
    assert [{:logger, :error, {{1, 2}, %{file: _, line: _}}}] = PureLogger.error({1, 2})
    assert [{:logger, :error, {{1, 2, 3}, %{file: _, line: _}}}] = PureLogger.error({1, 2, 3})
    assert [{:logger, :error, {%{a: 1}, %{}}}] = PureLogger.error(%{a: 1, b: 2, c: 3})
    assert [] = PureLogger.debug(%{a: 1, b: 2, c: 3})
  end
end
