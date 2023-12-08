defmodule Burrito.MixProject do
  use Mix.Project

  def project do
    [
      app: :burrito,
      version: String.trim(File.read!("VERSION")),
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "README",
        extras: ["README.md"]
      ],
      package: package(),
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
      organization: :burrito,
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/burrito-elixir/burrito",
        "Sponsor" => "https://github.com/sponsors/doawoo"
      }
    ]
  end

  defp deps do
    [
      {:req, "~> 0.2.0 or ~> 0.3.0"},
      {:typed_struct, "~> 0.2.0 or ~> 0.3.0", runtime: false},
      {:jason, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
