defmodule Mutare.Swoosh.ProviderOption do
  @moduledoc """
  :swoosh_provider_option removes provider-specific delivery options.

  A `Swoosh.Email.put_provider_option(email, key, value)` call collapses to the email (a piped
  stage to what was piped into it). A literal `provider_options:` map in Swoosh.Email.new/1
  loses one entry per mutant. This covers options such as template IDs, dynamic template data,
  and tracking settings.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @impl Mutare.Mutator
  def name, do: :swoosh_provider_option

  @impl Mutare.Mutator
  def variants, do: ~w(delete)

  @impl Mutare.Mutator
  def mutate(node) do
    case Calls.resolved_call_to(node, Swoosh.Email, [:put_provider_option, :new]) do
      {:ok, :put_provider_option, [email, _key, _value], _rebuild} -> [mutation(email)]
      {:ok, :new, [opts], rebuild} -> constructor_mutations(opts, rebuild)
      _ -> :skip
    end
  end

  defp constructor_mutations(opts, rebuild) do
    case SAST.opts_container(opts) do
      {:ok, {_kind, entries, wrap}} ->
        mutations =
          for {{_key, value} = entry, outer_index} <- Enum.with_index(entries),
              SAST.key(entry) == :provider_options,
              {:ok, {:map, options, wrap_map}} <- [SAST.map_container(value)],
              {_option, inner_index} <- Enum.with_index(options) do
            changed_map = options |> List.delete_at(inner_index) |> wrap_map.()
            changed_entry = SAST.replace_value(entry, changed_map)
            changed_opts = entries |> List.replace_at(outer_index, changed_entry) |> wrap.()
            mutation(rebuild.(:new, [changed_opts]))
          end

        case mutations do
          [] -> :skip
          mutations -> mutations
        end

      :error ->
        :skip
    end
  end

  defp mutation(node) do
    Mutation.new(node,
      variant: "delete",
      note: "provider option removed - no test asserts the provider option"
    )
  end
end
