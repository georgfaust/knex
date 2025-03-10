defmodule KnxStack.MixProject do
  use Mix.Project

  def project do
    [
      app: :knx,
      mod: {Knx, []},
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # {:csv, "~> 2.4", only: :test},
      # {:stream_data, "~> 0.5.0", only: :test},
      # {:assertions, "~> 0.10", only: :test},
      {:ex_const, "~> 0.1.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end
end
