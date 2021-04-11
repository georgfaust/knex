defmodule Knx.Auth do

  @invalid_key -1
  @delete_key 0xFF_FF_FF_FF
  @anonomymous_key 0xFF_FF_FF_FF
  @unauthorized 0xFF
  @default_level 3

  @moduledoc """

  purpose                        | audience         | access level
  ----------------------------------------------------------------
  read access                    | runtime          | level 3
  end-user adjustable parameters | controller       | level 3
  configuration                  | ETS              | level 2
  product manufacturer           | DevEdit/TransApp | level 1
  system manufacturer            | DevEdit/TransApp | level 0

  """
  defstruct keys: [0, 0, 0, @anonomymous_key],
            access_lvl: @default_level

  @me __MODULE__

  def key_write(%@me{access_lvl: access_lvl} = auth, _, level) when access_lvl > level,
    do: {auth, @unauthorized}

  def key_write(%@me{} = auth, @delete_key, level),
    do: {set_key(auth, @invalid_key, level), level}

  def key_write(%@me{} = auth, key, level),
    do: {set_key(auth, key, level), level}

  def auth(%@me{keys: keys} = auth, key) do
    level =
      case Enum.find_index(keys, fn k -> k == key end) do
        nil -> @default_level
        level -> level
      end

    %@me{auth | access_lvl: level}
  end

  def de_auth(%@me{} = auth), do: %@me{auth | access_lvl: @default_level}

  # ----
  defp set_key(%@me{keys: keys} = auth, key, level),
    do: %@me{auth | keys: List.replace_at(keys, level, key)}
end
