defmodule Mutare.Swoosh.Subject do
  @moduledoc """
  :swoosh_subject deletes the email subject.

  A direct subject(email, value) call is changed to subject(email, ""). In Swoosh.Email.new/1,
  the :subject option is removed, falling back to Swoosh's default empty subject.

  Where the core :string family also runs, the direct-call replacement takes Mutare's overlap
  precedence: the string-literal mutants on that subject argument (empty and sentinel) are
  dropped, leaving this family's single note-carrying mutant. On the new/1 side the option
  removal and the core empty-string mutant coexist (they are minted at different nodes) and are
  behaviourally equivalent.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @impl Mutare.Mutator
  def name, do: :swoosh_subject

  @impl Mutare.Mutator
  def variants, do: ~w(delete)

  @impl Mutare.Mutator
  def mutate(node, %{pipe_mode: pipe_mode}) do
    (call_mutations(node, pipe_mode) ++ new_option_mutations(node, pipe_mode)) |> present()
  end

  defp call_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Email, :subject) do
      {:ok, :subject, args, rebuild} ->
        with {index, value} <- SAST.value_arg(args, pipe_mode),
             false <- empty_subject?(value) do
          [mutation(rebuild.(:subject, List.replace_at(args, index, SAST.empty_string())))]
        else
          _ -> []
        end

      :error ->
        []
    end
  end

  defp new_option_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Email, :new) do
      {:ok, :new, args, rebuild} ->
        case SAST.new_opts_arg(args, pipe_mode) do
          {arg_index, {_kind, entries, wrap}} ->
            entries
            |> Enum.with_index()
            |> Enum.flat_map(fn {entry, entry_index} ->
              with :subject <- SAST.key(entry),
                   {_key, value} <- entry,
                   false <- empty_subject?(value) do
                mutated_entries = List.delete_at(entries, entry_index)

                [
                  mutation(
                    rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries)))
                  )
                ]
              else
                _ -> []
              end
            end)

          nil ->
            []
        end

      :error ->
        []
    end
  end

  defp empty_subject?(value), do: SAST.literal_value(value) == {:ok, ""}

  defp mutation(node) do
    Mutation.new(node,
      variant: "delete",
      note: "subject deleted - no test asserts the subject"
    )
  end

  defp present([]), do: :skip
  defp present([_ | _] = mutations), do: mutations
end
