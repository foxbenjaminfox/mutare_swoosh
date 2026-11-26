defmodule Mutare.Swoosh.MixProject do
  use Mix.Project

  @version "0.2.1"
  @source_url "https://github.com/foxbenjaminfox/mutare_swoosh"

  def project do
    [
      app: :mutare_swoosh,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Mutare mutators for Swoosh"
  end

  # Hex package metadata. Only runtime and doc artifacts
  # ship — never the test suite or fixtures.
  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Benjamin Fox"],
      links: %{
        "GitHub" => @source_url,
        "Mutare" => "https://hexdocs.pm/mutare",
        "Changelog" => "https://hexdocs.pm/mutare_swoosh/changelog.html"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp deps do
    [
      # The host mutation-testing engine. `mutare_swoosh` implements `Mutare.Mutator`
      # and rides only its public extension points (`Mutare.Calls`, `Mutare.AST`).
      # A consuming project depends on both as `:dev`/`:test` deps.
      #
      # The isolated Mix project in integration/ exercises real Swoosh. The unit
      # suite defines stand-ins under the real module names for import resolution.
      {:mutare, "~> 0.5.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  # `mix check` is the single quality gate: formatting, lint, and type analysis.
  # Any non-zero step aborts the rest, so a green run means all three passed.
  defp aliases do
    [check: ["format --check-formatted", "credo", "dialyzer"]]
  end

  # PLTs land in priv/plts so they can be cached (e.g. in CI) instead of being
  # rebuilt every run; :mix/:ex_unit are analyzed because mix.exs and test/support
  # participate.
  defp dialyzer do
    [
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts",
      plt_add_apps: [:mix, :ex_unit],
      flags: [:error_handling, :extra_return, :missing_return]
    ]
  end

  # ExDoc configuration. `mix docs` renders to `doc/` (gitignored). README is the
  # landing page; `Mutare.Swoosh.AST` is `@moduledoc false` plumbing and never
  # appears.
  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        "Mutator front": [Mutare.Swoosh],
        "Email-construction families": [
          Mutare.Swoosh.Recipient,
          Mutare.Swoosh.Sender,
          Mutare.Swoosh.Subject,
          Mutare.Swoosh.Body,
          Mutare.Swoosh.Header,
          Mutare.Swoosh.Attachment,
          Mutare.Swoosh.ProviderOption
        ],
        "Delivery family": [
          Mutare.Swoosh.Deliver
        ]
      ]
    ]
  end
end
