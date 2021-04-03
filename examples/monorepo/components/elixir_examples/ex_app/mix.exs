defmodule ExApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_app,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:ex_lib, path: "_build/deps/ex_lib", override: true},
        {:ex_sublib, path: "_build/deps/ex_sublib", override: true}
      ]
    ]
  end
end
