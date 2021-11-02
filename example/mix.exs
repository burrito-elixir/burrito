defmodule ExampleCliApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :example_cli_app,
      releases: releases(),
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def releases do
  [
    example_cli_app: [
      steps: [:assemble, &Burrito.wrap/1],
      burrito: [
        targets: [:darwin, :win64, :linux, :linux_musl],
        debug: Mix.env() != :prod,
        plugin: "./test_plugin/plugin.zig",
        no_clean: false,
      ]
    ]
  ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExampleCliApp, []}
    ]
  end

  defp deps do
    [
      {:burrito, path: "../"},
      # {:ex_termbox, "~> 1.0"},
    ]
  end
end
