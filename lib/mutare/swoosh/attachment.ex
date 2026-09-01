defmodule Mutare.Swoosh.Attachment do
  @moduledoc """
  :swoosh_attachment mutates attachment presence and disposition.

  Two kinds of mutation, separately ignorable by variant label:

    * whole-attachment removal (`delete`) — a `Swoosh.Email.attachment(email, ...)` call
      collapses to the email (piped stages become identity), and the singular `attachment:`
      option in Swoosh.Email.new/1 is dropped. A survivor means no test asserts the attachment
      exists. (Swoosh.Email.new/1 has no `attachments:` option, so none is matched.)
    * disposition swap (`inline` / `attachment`) — Swoosh exposes disposition on
      Swoosh.Attachment.new/2 through the :type option; type: :inline and type: :attachment are
      swapped where that option is present.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @impl Mutare.Mutator
  def name, do: :swoosh_attachment

  @impl Mutare.Mutator
  def variants, do: ~w(inline attachment delete)

  @impl Mutare.Mutator
  def mutate(node, %{pipe_mode: pipe_mode}) do
    (disposition_mutations(node, pipe_mode) ++
       delete_mutations(node, pipe_mode) ++ new_option_mutations(node, pipe_mode))
    |> present()
  end

  defp disposition_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Attachment, :new) do
      {:ok, :new, args, rebuild} -> type_swaps(args, pipe_mode, rebuild)
      :error -> []
    end
  end

  defp type_swaps(args, pipe_mode, rebuild) do
    with {opts_index, opts} <- SAST.effective_arg(args, pipe_mode, 2, 1),
         {:ok, {_kind, entries, wrap}} <- SAST.opts_container(opts) do
      entries
      |> Enum.with_index()
      |> Enum.flat_map(fn {entry, entry_index} ->
        with :type <- SAST.key(entry),
             {_key, value} <- entry,
             type when type in [:inline, :attachment] <- SAST.literal_atom(value) do
          target = target(type)
          mutated_entry = SAST.replace_value(entry, SAST.replace_atom(value, target))
          mutated_opts = wrap.(List.replace_at(entries, entry_index, mutated_entry))

          [
            Mutation.new(rebuild.(:new, List.replace_at(args, opts_index, mutated_opts)),
              variant: target,
              note:
                "attachment disposition changed to #{target} - no test asserts inline vs attachment"
            )
          ]
        else
          _ -> []
        end
      end)
    else
      _ -> []
    end
  end

  defp delete_mutations(node, pipe_mode) do
    with {:ok, :attachment, args, _rebuild} <-
           Calls.resolved_call_to(node, Swoosh.Email, :attachment),
         {_index, _value} <- SAST.value_arg(args, pipe_mode),
         collapsed when not is_nil(collapsed) <- SAST.collapse_to_email(args, pipe_mode) do
      [delete_mutation(collapsed)]
    else
      _ -> []
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
              if SAST.key(entry) == :attachment do
                mutated_entries = List.delete_at(entries, entry_index)

                [
                  delete_mutation(
                    rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries)))
                  )
                ]
              else
                []
              end
            end)

          nil ->
            []
        end

      :error ->
        []
    end
  end

  defp delete_mutation(node) do
    Mutation.new(node,
      variant: "delete",
      note: "attachment removed - no test asserts the attachment is present"
    )
  end

  defp target(:inline), do: :attachment
  defp target(:attachment), do: :inline

  defp present([]), do: :skip
  defp present([_ | _] = mutations), do: mutations
end
