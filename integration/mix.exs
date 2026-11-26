defmodule MutareSwooshIntegration.MixProject do
  use Mix.Project

  def project do
    [
      app: :mutare_swoosh_integration,
      version: "0.0.0",
      elixir: "~> 1.18",
      deps: [
        {:mutare_swoosh, path: ".."},
        {:swoosh, "~> 1.30.0", only: :test}
      ]
    ]
  end
end
