defmodule Dask.MixProject do
  use Mix.Project

  def project do
    [
      app: :dask,
      version: "0.0.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        docs: :dev
      ],
      test_coverage: [tool: ExCoveralls],
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def deps do
    [
      {:excoveralls, "~> 0.12", only: :test},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: ".plts",
      plt_file: {:no_warn, ".plts/dialyzer.plt"},
      flags: [:error_handling, :race_conditions, :underspecs]
    ]
  end

  def aliases do
    [dialyzer: [&mkdir_plts/1, "dialyzer"]]
  end

  defp mkdir_plts(_), do: File.mkdir_p!(".plts")
end