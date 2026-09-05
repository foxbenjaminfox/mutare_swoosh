defmodule Mutare.Swoosh.Deliver do
  @moduledoc """
  :swoosh_deliver drops email delivery while keeping the success shape.

  A `deliver(email)` / `deliver(email, config)` call on a configured mailer is replaced by the
  literal `{:ok, %{}}`, and `deliver!/1,2` by `%{}` — the shapes a successful Swoosh delivery
  returns, with nothing sent. A piped stage becomes `Kernel.then(fn _ -> ... end)` so the pipe
  stays legal and the email is still built. A survivor asks the pointed question: does any test
  assert the email was actually sent (`Swoosh.TestAssertions.assert_email_sent/1`)?

  The mailer module is application-specific, so this is a configurable mutator — without the
  `mailer:` option the family produces no mutations:

      [mutators: [:builtins, {Mutare.Swoosh.Deliver, mailer: MyApp.Mailer}]]

  `mailer:` takes one module or a list (`mailer: [MyApp.Mailer, MyApp.AdminMailer]`); every listed
  mailer's mutants record under the one `:swoosh_deliver` name. To report mailers separately, list
  the family twice with different `mailer:`/`as:` — Mutare's multi-instance convention. Direct,
  aliased, and piped calls all match. `Mutare.Swoosh.all/1` configures the family while splicing
  the whole package in.

  Each mutant is tagged with the function it replaces (`deliver` / `deliver!`) as its ignore
  variant, so `# mutare:ignore[swoosh_deliver:deliver!]` suppresses only the raising form.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @valid_options [:mailer]
  @functions [:deliver, :deliver!]

  @impl Mutare.Mutator
  def name, do: :swoosh_deliver

  @impl Mutare.Mutator
  def variants, do: ~w(deliver deliver!)

  # Options are parsed once, at spec resolution, and reach `mutate/2` as `context.config`: the
  # configured mailers as `Mutare.Calls.module_key/1`s, ready to compare against a resolved call's
  # module. A typo'd option raises here, at startup, next to Mutare's own option validation.
  @impl Mutare.Mutator
  def init(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "Mutare.Swoosh.Deliver options must be a keyword list, got: #{inspect(opts)}"
    end

    validate_option_keys!(opts)
    opts |> Keyword.get(:mailer, []) |> parse_mailer!()
  end

  defp validate_option_keys!(opts) do
    case Keyword.keys(opts) -- @valid_options do
      [] ->
        :ok

      unknown ->
        raise ArgumentError,
              "unknown Mutare.Swoosh.Deliver options: #{inspect(unknown)} — valid options are " <>
                inspect(@valid_options)
    end
  end

  # One module or a list of modules, each normalised to its module key. An unset `mailer:` reads
  # as `[]` — the family fires on nothing — and so does an explicit `mailer: nil`; `nil` *inside*
  # a list is a malformed option (it is `is_atom/1`-true, but names no module).
  defp parse_mailer!(nil), do: []
  defp parse_mailer!(module) when is_atom(module), do: [Calls.module_key(module)]

  defp parse_mailer!(modules) when is_list(modules) do
    if Enum.all?(modules, &(is_atom(&1) and not is_nil(&1))),
      do: Enum.map(modules, &Calls.module_key/1),
      else: raise_mailer!(modules)
  end

  defp parse_mailer!(other), do: raise_mailer!(other)

  @spec raise_mailer!(term()) :: no_return()
  defp raise_mailer!(value) do
    raise ArgumentError,
          "Mutare.Swoosh.Deliver :mailer must be a module or a list of modules, got: " <>
            inspect(value)
  end

  # `context.config` is what `init/1` returned, on every path core dispatches through. A context
  # without it is a programming error, so the second clause fails loudly rather than letting the
  # family silently produce nothing.
  @impl Mutare.Mutator
  def mutate(node, %{config: mailers, pipe_mode: pipe_mode}) when is_list(mailers) do
    with {mailer, fun, args, _rebuild} <- Calls.resolved_call(node),
         true <- mailer in mailers and fun in @functions,
         true <- Mutare.Mutator.effective_arity(args, pipe_mode) in [1, 2] do
      [mutation(fun, pipe_mode)]
    else
      _ -> :skip
    end
  end

  def mutate(_node, context) do
    raise ArgumentError,
          "Mutare.Swoosh.Deliver.mutate/2 expected core's callback context with the " <>
            "init/1-parsed :config and a :pipe_mode, got: #{inspect(context)}"
  end

  defp mutation(:deliver, pipe_mode) do
    Mutation.new(SAST.constant_stage(SAST.ok_empty_map(), pipe_mode),
      variant: "deliver",
      note:
        "deliver replaced by {:ok, %{}} - nothing is sent; no test asserts delivery " <>
          "(Swoosh.TestAssertions.assert_email_sent)"
    )
  end

  defp mutation(:deliver!, pipe_mode) do
    Mutation.new(SAST.constant_stage(SAST.empty_map(), pipe_mode),
      variant: "deliver!",
      note:
        "deliver! replaced by %{} - nothing is sent; no test asserts delivery " <>
          "(Swoosh.TestAssertions.assert_email_sent)"
    )
  end
end
