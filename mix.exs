defmodule CellularAutomata.MixProject do
  use Mix.Project

  def project do
    [
      app: :cellular_automata,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "CellularAutomata",
      source_url: "https://github.com/sragli/cellular_automata",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description() do
    "Elixir module to create and analyse cellular automata."
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/sragli/cellular_automata"}
    ]
  end

  defp docs() do
    [
      main: "CellularAutomata",
      extras: ["README.md", "LICENSE", "CHANGELOG"]
    ]
  end

  defp deps do
    []
  end
end
