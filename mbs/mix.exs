defmodule MBS.MixProject do
  use Mix.Project

  def project do
    [
      app: :mbs,
      version: "0.0.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: MBS],
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
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def deps do
    [
      {:jason, "~> 1.2"},
      {:excoveralls, "~> 0.12", only: :test},
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

  def aliases do
    [dialyzer: [&mkdir_plts/1, "dialyzer"]]
  end

  defp mkdir_plts(_), do: File.mkdir_p!(".plts")
end
