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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.2.0"},
      {:jason, "~> 1.2"}
    ]
  end
end
