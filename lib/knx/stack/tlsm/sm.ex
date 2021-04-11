defmodule Knx.Stack.Tlsm.Sm do
  @index %{
    closed: 0,
    o_idle: 1,
    o_wait: 2
  }

  @table %{
    e00: [{:o_idle, :a01}, {:closed, :a06}, {:closed, :a06}],
    e01: [{:o_idle, :a01}, {:o_idle, :a10}, {:o_wait, :a10}],
    e02: [{:closed, :a00}, {:closed, :a05}, {:closed, :a05}],
    e03: [{:closed, :a00}, {:o_idle, :a00}, {:o_wait, :a00}],
    e04: [{:closed, :a10}, {:o_idle, :a02}, {:o_wait, :a02}],
    e05: [{:closed, :a10}, {:o_idle, :a03}, {:o_wait, :a03}],
    e06: [{:closed, :a10}, {:o_idle, :a04}, {:o_wait, :a04}],
    e07: [{:closed, :a10}, {:o_idle, :a10}, {:o_wait, :a10}],
    e08: [{:closed, :a10}, {:closed, :a06}, {:o_idle, :a08}],
    e09: [{:closed, :a10}, {:closed, :a06}, {:closed, :a06}],
    e10: [{:closed, :a10}, {:o_idle, :a10}, {:o_wait, :a10}],
    e11: [{:closed, :a10}, {:closed, :a06}, {:closed, :a06}],
    e12: [{:closed, :a10}, {:closed, :a06}, {:o_wait, :a09}],
    e13: [{:closed, :a10}, {:closed, :a06}, {:closed, :a06}],
    e14: [{:closed, :a10}, {:o_idle, :a10}, {:o_wait, :a10}],
    e15: [{:closed, :a05}, {:o_wait, :a07}, {:closed, :a06}],
    e16: [{:closed, :a00}, {:closed, :a06}, {:closed, :a06}],
    e17: [{:closed, :a00}, {:o_idle, :a00}, {:o_wait, :a09}],
    e18: [{:closed, :a00}, {:o_idle, :a00}, {:closed, :a06}],
    e19: [{:closed, :a00}, {:o_idle, :a13}, {:o_wait, :a13}],
    e20: [{:closed, :a00}, {:closed, :a05}, {:closed, :a05}],
    e21: [{:closed, :a00}, {:o_idle, :a00}, {:o_wait, :a00}],
    e22: [{:closed, :a00}, {:o_idle, :a00}, {:o_wait, :a00}],
    e23: [{:closed, :a00}, {:o_idle, :a00}, {:o_wait, :a00}],
    e24: [{:closed, :a00}, {:o_idle, :a00}, {:o_wait, :a00}],
    e25: [{:o_idle, :a12}, {:closed, :a06}, {:closed, :a06}],
    e26: [{:closed, :a15}, {:closed, :a14}, {:closed, :a14}],
    e27: [{:closed, :a00}, {:o_idle, :a00}, {:o_wait, :a00}]
  }

  @type handler_t :: :closed | :o_idle | :o_wait

  @spec state_handler(
          Knx.Stack.Tlsm.Event.event_t(),
          handler_t()
        ) :: {handler_t(), Knx.Stack.Tlsm.Action.action_t()}

  def state_handler(event, handler) do
    row = @table[event]
    Enum.at(row, @index[handler])
  end
end
