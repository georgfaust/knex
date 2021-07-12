defmodule Knx.Stack.Nl do
  @hops_unlimited 7

  import PureLogger

  alias Knx.State, as: S
  alias Knx.Frame, as: F
  require Knx.Defs
  import Knx.Defs

  # def handle({:nl, :req, %F{hops: :hops_unlimited} = frame}, %S{addr: addr}),
  #   do: [{:dl, :req, %F{frame | src: addr, hops: @hops_unlimited}}]

  # def handle({:nl, :req, %F{} = frame}, %S{addr: addr, hops: hops_nw_param}),
  #   do: [{:dl, :req, %F{frame | src: addr, hops: hops_nw_param}}]

  def handle({:nl, :req, %F{hops: :hops_unlimited} = frame}, %S{addr: addr}),
    do: [{:dl_cemi, :req, %F{frame | src: addr, hops: @hops_unlimited}}]

  def handle({:nl, :req, %F{} = frame}, %S{addr: addr, hops: hops_nw_param}),
    do: [{:dl_cemi, :req, %F{frame | src: addr, hops: hops_nw_param}}]

  def handle({:nl, :ind, %F{addr_t: addr_t(:ind), dest: addr} = frame}, %S{addr: addr}),
    do: [{:tl, :ind, frame}]

  def handle({:nl, :ind, %F{addr_t: addr_t(:ind), dest: _dest}}, %S{addr: _addr}),
    do: debug({:not_addressed_frame_dropped, dest: _dest, addr: _addr})

  def handle({:nl, prim, %F{} = frame}, %S{}),
    do: [{:tl, prim, frame}]
end
