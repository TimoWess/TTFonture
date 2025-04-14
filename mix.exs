defmodule TTFonture.MixProject do
  use Mix.Project

  def project do
    [
      app: :ttfonture,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "TTFonture",
      source_url: "https://github.com/TimoWess/TTFonture",
      docs: &docs/0
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "TTFonture",
      extras: ["README.md", "LICENSE"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
