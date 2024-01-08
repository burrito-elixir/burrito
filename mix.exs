defmodule Burrito.MixProject do
  use Mix.Project

  def project do
    [
      app: :burrito,
      description:
        "Burrito is our answer to the problem of distributing Elixir applications across varied environments. Turn your Elixir application into a simple, self-contained, single-file executable for MacOS, Linux, and Windows.",
      version: String.trim(File.read!("VERSION")),
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  def package do
    [
      maintainers: ["Digit"],
      name: :burrito,
      licenses: ["MIT"],
      files: ~w(lib LICENSE VERSION mix.exs README.md .formatter.exs src bin _dummy_plugin.zig build.zig),
      links: %{
        "Github" => "https://github.com/burrito-elixir/burrito",
        "Sponsor" => "https://github.com/sponsors/doawoo"
      }
    ]
  end

  defp deps do
    [
      {:req, "0.4.0"},
      {:typed_struct, "~> 0.2.0 or ~> 0.3.0", runtime: false},
      {:jason, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
