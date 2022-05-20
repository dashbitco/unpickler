defmodule Unpickler.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "A library for loading data in the Python's pickle format"

  def project do
    [
      app: :unpickler,
      version: @version,
      description: @description,
      name: "Unpickler",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, "~> 0.28", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Unpickler",
      source_url: "https://github.com/dashbitco/unpickler",
      source_ref: "v#{@version}",
      groups_for_modules: [
        Types: [Unpickler.Global, Unpickler.Object]
      ]
    ]
  end

  def package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/dashbitco/unpickler"
      }
    ]
  end
end
