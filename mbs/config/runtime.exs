import Config

config :logger, level: System.get_env("LOG_LEVEL", "info") |> String.to_existing_atom()
