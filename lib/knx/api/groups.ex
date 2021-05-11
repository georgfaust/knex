# defmodule Knx.Api.Group do
#   alias Knx.Frame, as: F

#   def write(name, asap, data) do
#     Shell.Server.dispatch(
#       name,
#       {:go, :req, %F{apci: :group_write, asap: asap, service: :t_data_group, data: data}}
#     )
#   end
# end
