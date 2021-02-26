defmodule MBS.MixProject do
  use Mix.Project

  def project do
    [
      app: :mbs,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: MBS],
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  def deps do
    [
      {:workflow, path: "../workflow"},
      {:jason, "~> 1.2"},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: ".plts",
      plt_file: {:no_warn, ".plts/dialyzer.plt"}
    ]
  end
end
