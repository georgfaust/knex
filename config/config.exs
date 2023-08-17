import Config

config :knx, :log_min_level, :debug
config :logger, :console, format: "$time $metadata[$level] $message\n"

import_config "#{Mix.env}.exs"
