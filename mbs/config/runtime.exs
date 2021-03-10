import Config

config :logger, level: System.get_env("LOG_LEVEL", "info") |> String.to_existing_atom()
config :elixir, ansi_enabled: System.get_env("LOG_COLOR", "true") |> String.to_existing_atom()
