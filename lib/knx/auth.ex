defmodule Knx.Auth do
  alias Knx.Frame, as: F
  alias Knx.State, as: S

  @invalid_key -1
  @delete_key 0xFF_FF_FF_FF
  @anon_key 0xFF_FF_FF_FF
  @unauthorized 0xFF
  @default_lvl 3

  @moduledoc """

  purpose                        | audience         | access lvl
  ----------------------------------------------------------------
  read access                    | runtime          | lvl 3
  end-user adjustable parameters | controller       | lvl 3
  configuration                  | ETS              | lvl 2
  product manufacturer           | DevEdit/TransApp | lvl 1
  system manufacturer            | DevEdit/TransApp | lvl 0

  """
  defstruct keys: [0, 0, 0, @anon_key],
            access_lvl: @default_lvl

  @me __MODULE__

  def handle({:auth, :req, %F{apci: :auth_req} = frame}, %S{}) do
    [{:al, :req, frame}]
  end

  def handle({:auth, :req, %F{apci: :key_write} = frame}, %S{}) do
    [{:al, :req, frame}]
  end

  def handle(
        {:auth, :ind, %F{apci: :auth_req, data: [key], service: service}},
        %S{auth: %@me{} = auth} = state
      ) do
    auth = auth(auth, key)

    {%{state | auth: auth},
     [{:al, :req, %F{apci: :auth_resp, data: [auth.access_lvl], service: service}}]}
  end

  def handle(
        {:auth, :ind, %F{apci: :key_write, data: [lvl, key], service: service}},
        %S{auth: %@me{} = auth} = state
      ) do
    {auth, lvl} = key_write(auth, key, lvl)
    {%{state | auth: auth}, [{:al, :req, %F{apci: :key_resp, data: [lvl], service: service}}]}
  end

  def de_auth(%@me{} = auth), do: %@me{auth | access_lvl: @default_lvl}

  # ----

  defp key_write(%@me{access_lvl: access_lvl} = auth, _, lvl) when access_lvl > lvl,
    do: {auth, @unauthorized}

  defp key_write(%@me{} = auth, @delete_key, lvl),
    do: {set_key(auth, @invalid_key, lvl), lvl}

  defp key_write(%@me{} = auth, key, lvl),
    do: {set_key(auth, key, lvl), lvl}

  defp auth(%@me{keys: keys} = auth, key) do
    lvl =
      case Enum.find_index(keys, fn k -> k == key end) do
        nil -> @default_lvl
        lvl -> lvl
      end

    %@me{auth | access_lvl: lvl}
  end

  defp set_key(%@me{keys: keys} = auth, key, lvl),
    do: %@me{auth | keys: List.replace_at(keys, lvl, key)}
end
