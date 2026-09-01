defmodule Mutare.Swoosh.ProviderOption do
  @moduledoc """
  :swoosh_provider_option removes provider-specific delivery options.

  A `Swoosh.Email.put_provider_option(email, key, value)` call collapses to the email (piped
  stages become identity). Provider options carry exactly the delivery behaviour that is easy to
  leave untested — template ids, dynamic template data, tracking settings — so a survivor means
  no test asserts the option reaches the provider.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @impl Mutare.Mutator
  def name, do: :swoosh_provider_option

  @impl Mutare.Mutator
  def variants, do: ~w(delete)

  @impl Mutare.Mutator
  def mutate(node, %{pipe_mode: pipe_mode}) do
    with {:ok, :put_provider_option, args, _rebuild} <-
           Calls.resolved_call_to(node, Swoosh.Email, :put_provider_option),
         3 <- Mutator.effective_arity(args, pipe_mode),
         collapsed when not is_nil(collapsed) <- SAST.collapse_to_email(args, pipe_mode) do
      [
        Mutation.new(collapsed,
          variant: "delete",
          note: "provider option removed - no test asserts the provider option"
        )
      ]
    else
      _ -> :skip
    end
  end
end
