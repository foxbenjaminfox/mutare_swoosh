# Mirrors the mutare / mutare_ecto house configuration: recursive AST-walking
# code trips the depth/complexity heuristics without being any less clear, so
# those two checks are off; everything else runs at defaults.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      strict: false,
      checks: %{
        disabled: [
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.Nesting, []}
        ]
      }
    }
  ]
}
