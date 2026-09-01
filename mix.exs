defmodule Mutare.Swoosh.MixProject do
  use Mix.Project

  @version "0.1.0"
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
    "Custom Mutare mutators for the Swoosh email surface — " <>
      "recipients, sender, subject, bodies, headers, attachments, and delivery."
  end

  # Hex package metadata. The `mutare` core is still a `path:` dependency, so an
  # actual `mix hex.publish` stays blocked until Mutare itself ships to Hex — this
  # section keeps the manifest ready for that day. Only runtime and doc artifacts
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
      # A path dep for local development until `mutare` is published; a consuming
      # project depends on both as `:dev`/`:test` deps.
      #
      # Swoosh itself is deliberately NOT a dependency, not even in :test: the
      # mutators match calls purely syntactically, and the test suite's stand-ins
      # (test/support/swoosh_stubs.ex) claim the real `Swoosh.Email` /
      # `Swoosh.Attachment` module names so bare-import resolution reflects on real
      # exports — a real :swoosh test dep would collide with them. Stub fidelity is
      # maintained against Swoosh's source by hand (see the stubs' comments).
      {:mutare, path: "../mutare"},
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
