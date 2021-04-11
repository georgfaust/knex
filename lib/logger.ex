defmodule PureLogger do
  @levels [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]

  for level <- @levels do
    defmacro unquote(level)(data) do
      maybe_log(unquote(level), data, __CALLER__)
    end
  end

  def maybe_log(level, data, caller) do
    meta = Map.take(caller, [:file, :line])

    if do_log?(level) do
      quote do
        [
          {
            :logger,
            unquote(level),
            {
              unquote(data),
              unquote(Macro.escape(meta))
            }
          }
        ]
      end
    else
      []
    end
  end

  defp do_log?(level) do
    min_level = Application.get_env(:knx, :log_min_level, :all)
    :logger.compare_levels(level, min_level) == :gt
  end
end
