defmodule Burrito.MixProject do
  use Mix.Project

  def project do
    [
      app: :burrito,
      version: String.trim(File.read!("VERSION")),
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.6"},
      {:req, "~> 0.2.0 or ~> 0.3.0"},
      {:typed_struct, "~> 0.2.0 or ~> 0.3.0", runtime: false},
      {:jason, "~> 1.2"}
    ]
  end
end
