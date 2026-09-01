defmodule Mutare.Swoosh.Deliver do
  @moduledoc """
  :swoosh_deliver drops email delivery while keeping the success shape.

  A `deliver(email)` / `deliver(email, config)` call on the configured mailer is replaced by the
  literal `{:ok, %{}}`, and `deliver!/1,2` by `%{}` — the shapes a successful Swoosh delivery
  returns, with nothing sent. A piped stage becomes `Kernel.then(fn _ -> ... end)` so the pipe
  stays legal and the email is still built. A survivor asks the pointed question: does any test
  assert the email was actually sent (`Swoosh.TestAssertions.assert_email_sent/1`)?

  The mailer module is application-specific, so this is a configurable mutator — without the
  `mailer:` option the family produces no mutations:

      [mutators: [:builtins, {Mutare.Swoosh.Deliver, mailer: MyApp.Mailer}]]

  `mailer:` accepts a single module or a list of modules. Direct, aliased, and piped calls all
  match. `Mutare.Swoosh.all/1` configures the family while splicing the whole package in.

  Each mutant is tagged with the function it replaces (`deliver` / `deliver!`) as its ignore
  variant, so `# mutare:ignore[swoosh_deliver:deliver!]` suppresses only the raising form.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @impl Mutare.Mutator
  def name, do: :swoosh_deliver

  @impl Mutare.Mutator
  def variants, do: ~w(deliver deliver!)

  @impl Mutare.Mutator
  def init(opts) do
    opts = Keyword.validate!(opts, mailer: [])
    mailers = List.wrap(opts[:mailer])

    unless Enum.all?(mailers, &is_atom/1) do
      raise ArgumentError,
            "#{inspect(__MODULE__)} expects mailer: to be a module or a list of modules, " <>
              "got: #{inspect(opts[:mailer])}"
    end

    mailers
  end

  @impl Mutare.Mutator
  def mutate(node, %{pipe_mode: pipe_mode} = context) do
    context
    |> mailers()
    |> Enum.find_value(:skip, fn mailer ->
      case Calls.resolved_call_to(node, mailer, [:deliver, :deliver!]) do
        {:ok, fun, args, _rebuild} -> deliver_mutations(fun, args, pipe_mode)
        :error -> nil
      end
    end)
  end

  defp deliver_mutations(fun, args, pipe_mode) do
    if Mutare.Mutator.effective_arity(args, pipe_mode) in [1, 2] do
      [mutation(fun, pipe_mode)]
    else
      nil
    end
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

  # `context.config` carries what `init/1` returned when the instance was resolved through the
  # transform; direct dispatch in tests may hand raw `context.opts` instead.
  defp mailers(%{config: mailers}) when is_list(mailers), do: mailers
  defp mailers(%{opts: opts}) when is_list(opts), do: List.wrap(Keyword.get(opts, :mailer))
  defp mailers(_context), do: []
end
