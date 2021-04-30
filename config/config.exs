import Config

config :knx, :log_min_level, :debug
config :logger, :console, format: "$time $metadata[$level] $levelpad$message\n"

