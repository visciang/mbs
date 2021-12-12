defmodule DialyzerPlt.MixProject do
  use Mix.Project

  def project do
    [
      app: :dialyzer_plt,
      version: "0.0.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "./dialyzer.plt"},
      flags: [:error_handling, :race_conditions, :underspecs]
    ]
  end
end
