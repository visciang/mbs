defmodule ExLib.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_lib,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:ex_sublib, path: "../ex_sublib"}
      ]
    ]
  end
end
