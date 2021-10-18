defmodule Knx.Stack.Tlsm.Action do
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  @prio_system 0

  @spec action(atom, State.t(), Frame.t()) ::
          { State.t(),
           [
             {:al, :conf | :ind, Frame.t()}
             | {:timer, :restart | :start | :stop, {atom, atom}}
             | {:tl, :req, Frame.t()}
             | {:tlsm, :req, Frame.t()}
           ]}
  def action(:a00, %S{} = state, _) do
    {state, []}
  end

  def action(:a01, %S{} = state, %F{src: src}) do
    {
      %S{state | c_addr: src, s_seq: 0, r_seq: 0},
      [{:timer, :start, {:tlsm, :connection}}, {:al, :ind, %F{src: src, service: :t_connect}}]
    }
  end

  def action(:a02, %S{c_addr: c_addr, r_seq: r_seq} = state, %F{} = frame) do
    {
      %S{state | r_seq: inc(r_seq)},
      [
        {:tl, :req, %F{service: :t_ack, prio: @prio_system, dest: c_addr, seq: r_seq}},
        {:al, :ind, frame},
        {:timer, :restart, {:tlsm, :connection}}
      ]
    }
  end

  def action(:a03, %S{c_addr: c_addr} = state, %F{seq: seq}) do
    {
      state,
      [
        {:timer, :restart, {:tlsm, :connection}},
        {:tl, :req, %F{service: :t_ack, prio: @prio_system, dest: c_addr, seq: seq}}
      ]
    }
  end

  def action(:a04, %S{c_addr: c_addr} = state, %F{seq: seq}) do
    {
      state,
      [
        {:timer, :restart, {:tlsm, :connection}},
        {:tl, :req, %F{service: :t_nak, prio: @prio_system, dest: c_addr, seq: seq}}
      ]
    }
  end

  def action(:a05, %S{} = state, %F{confirm: confirm}) do
    {
      %S{state | c_addr: nil},
      [
        {:timer, :stop, {:tlsm, :connection}},
        {:timer, :stop, {:tlsm, :ack}},
        {:al, :ind, %F{service: :t_discon, confirm: confirm}}
      ]
    }
  end

  def action(:a06, %S{c_addr: c_addr} = state, _) do
    {
      state,
      [
        {:timer, :stop, {:tlsm, :connection}},
        {:timer, :stop, {:tlsm, :ack}},
        {:al, :ind, %F{service: :t_discon}},
        {:tl, :req, %F{service: :t_discon, prio: @prio_system, dest: c_addr, seq: 0}}
      ]
    }
  end

  def action(:a07, %S{c_addr: c_addr, s_seq: s_seq} = state, %F{} = frame) do
    {
      %S{state | stored_frame: frame, rep: 0},
      [
        {:timer, :restart, {:tlsm, :connection}},
        {:timer, :start, {:tlsm, :ack}},
        {:tl, :req, %F{frame | dest: c_addr, seq: s_seq}}
      ]
    }
  end

  def action(:a08, %S{stored_frame: stored_frame, s_seq: s_seq} = state, %F{}) do
    {recalled_frame, state} = recall_frame(state)

    {
      %S{state | stored_frame: nil, s_seq: inc(s_seq)},
      [
        {:timer, :restart, {:tlsm, :connection}},
        {:timer, :stop, {:tlsm, :ack}},
        {:al, :conf, stored_frame}
      ] ++ recalled_frame
    }
  end

  def action(:a09, %S{stored_frame: stored_frame, rep: rep} = state, %F{}) do
    {
      %S{state | rep: rep + 1},
      [
        {:timer, :restart, {:tlsm, :connection}},
        {:timer, :stop, {:tlsm, :ack}},
        {:tl, :req, stored_frame}
      ]
    }
  end

  def action(:a10, %S{} = state, %F{src: src}) do
    {
      %S{state | stored_frame: nil},
      [
        {:tl, :req, %F{service: :t_discon, prio: @prio_system, dest: src, seq: 0}}
      ]
    }
  end

  def action(:a11, %S{deferred_frames: deferred_frames} = state, %F{} = frame) do
    {
      %S{state | deferred_frames: deferred_frames ++ [frame]},
      []
    }
  end

  def action(:a12, %S{} = state, %F{dest: dest}) do
    {
      %S{state | c_addr: dest, s_seq: 0, r_seq: 0},
      [
        {:timer, :start, {:tlsm, :connection}},
        {:tl, :req, %F{dest: dest, prio: @prio_system, service: :t_connect}}
      ]
    }
  end

  def action(:a13, %S{} = state, %F{}) do
    {
      state,
      [
        {:al, :conf, %F{service: :t_connect}}
      ]
    }
  end

  def action(:a14, %S{c_addr: c_addr} = state, %F{}) do
    {
      state,
      [
        {:timer, :stop, {:tlsm, :connection}},
        {:timer, :stop, {:tlsm, :ack}},
        {:al, :conf, %F{service: :t_discon}},
        {:tl, :req, %F{service: :t_discon, prio: @prio_system, dest: c_addr, seq: 0}}
      ]
    }
  end

  def action(:a15, %S{c_addr: c_addr} = state, _) do
    {
      state,
      [
        {:timer, :stop, {:tlsm, :connection}},
        {:timer, :stop, {:tlsm, :ack}},
        {:al, :conf, %F{service: :t_discon, src: c_addr}}
      ]
    }
  end

  # ---

  defp inc(seq), do: rem(seq + 1, 0x10)

  defp recall_frame(%S{deferred_frames: [frame | deferred_frames]} = state),
    do: {[{:tlsm, :req, frame}], %S{state | deferred_frames: deferred_frames}}

  defp recall_frame(%S{deferred_frames: []} = state),
    do: {[], state}
end
