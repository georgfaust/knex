defmodule Knx.Stack.DlCemi do
  alias Knx.State, as: S
  alias Knx.Frame, as: F

  def handle({:dl_cemi, :req, %F{} = frame}, %S{}) do
    data_cemi_frame = Knx.KnxnetIp.DataCemiFrame.handle_knx_frame_struct2(:req, frame)
    # :logger.debug("DL CEMI DOWN 1 #{inspect data_cemi_frame}")
    data_cemi_frame = Knx.KnxnetIp.DataCemiFrame.create(data_cemi_frame)
    # :logger.debug("DL CEMI DOWN 2 #{inspect data_cemi_frame}")
    [{:driver, :transmit, data_cemi_frame}]
  end

  def handle({:dl_cemi, :up, cemi_frame}, %S{}) do
    data_cemi_frame = Knx.KnxnetIp.DataCemiFrame.handle(cemi_frame)
    {prim, frame} = Knx.KnxnetIp.DataCemiFrame.knx_frame_struct2(data_cemi_frame)
    # :logger.debug("DL_CEMI UP #{inspect {prim, frame}}")
    [{:nl, prim, frame}, {:knip, :from_knx, frame}]
  end

  # {:knip, :from_knx, @knx_frame}, -> handled ip_inderface.ex 1187

  # in knxnetip :dl -> :dl_cemi umbenennen

  # IGMP:
  #   {:knip, :from_ip,
  #     {@ets_tunnelling_data_endpoint,
  #     <<

  # IGMP-socket aufmachen KNX-MC-IP und KNX-port
end
