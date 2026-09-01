defmodule Mutare.Swoosh.Sender do
  @moduledoc """
  :swoosh_sender swaps from and reply_to in Swoosh email construction, and removes reply_to.

  A literal list reply_to value is not changed into from, because Swoosh.Email.from/2 accepts a
  single mailbox while reply_to/2 may accept a list. The removal has no such restriction: a
  `reply_to(email, value)` call collapses to the email (piped stages become identity), and the
  `reply_to:` option in Swoosh.Email.new/1 is dropped — replies then silently go to `from`.

  No `from` removal is minted: Swoosh validates the sender at delivery, so that mutant would
  only crash, telling the suite nothing.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @fields ~w(from reply_to)a

  @impl Mutare.Mutator
  def name, do: :swoosh_sender

  @impl Mutare.Mutator
  def variants, do: ~w(from reply_to delete)

  @impl Mutare.Mutator
  def mutate(node, %{pipe_mode: pipe_mode}) do
    (call_mutations(node, pipe_mode) ++ new_option_mutations(node, pipe_mode)) |> present()
  end

  defp call_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Email, @fields) do
      {:ok, fun, args, rebuild} ->
        case SAST.value_arg(args, pipe_mode) do
          {_index, value} ->
            swap_mutations(fun, value, args, rebuild) ++ drop_mutations(fun, args, pipe_mode)

          nil ->
            []
        end

      :error ->
        []
    end
  end

  defp swap_mutations(fun, value, args, rebuild) do
    case target(fun, value) do
      nil -> []
      target -> [swap_mutation(rebuild.(target, args), target)]
    end
  end

  defp drop_mutations(:reply_to, args, pipe_mode) do
    case SAST.collapse_to_email(args, pipe_mode) do
      nil -> []
      collapsed -> [drop_mutation(collapsed)]
    end
  end

  defp drop_mutations(:from, _args, _pipe_mode), do: []

  defp new_option_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Email, :new) do
      {:ok, :new, args, rebuild} ->
        case SAST.new_opts_arg(args, pipe_mode) do
          {arg_index, {kind, entries, wrap}} ->
            entries
            |> Enum.with_index()
            |> Enum.flat_map(fn {entry, entry_index} ->
              case SAST.key(entry) do
                key when key in @fields ->
                  option_key_swap(
                    kind,
                    entry,
                    entries,
                    entry_index,
                    wrap,
                    args,
                    arg_index,
                    rebuild
                  ) ++
                    option_drop(key, entries, entry_index, wrap, args, arg_index, rebuild)

                _other ->
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

  defp option_key_swap(kind, entry, entries, entry_index, wrap, args, arg_index, rebuild) do
    with key when key in @fields <- SAST.key(entry),
         {_key, value} <- entry,
         target when not is_nil(target) <- target(key, value),
         true <- SAST.unique_key?(kind, entries, target) do
      mutated_entries = List.replace_at(entries, entry_index, SAST.replace_key(entry, target))

      [
        swap_mutation(
          rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries))),
          target
        )
      ]
    else
      _ -> []
    end
  end

  defp option_drop(:reply_to, entries, entry_index, wrap, args, arg_index, rebuild) do
    mutated_entries = List.delete_at(entries, entry_index)

    [drop_mutation(rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries))))]
  end

  defp option_drop(:from, _entries, _entry_index, _wrap, _args, _arg_index, _rebuild), do: []

  defp target(:from, _value), do: :reply_to

  defp target(:reply_to, value) do
    case SAST.list_container(value) do
      {:ok, _items, _wrap} -> nil
      :error -> :from
    end
  end

  defp swap_mutation(node, target) do
    Mutation.new(node,
      variant: target,
      note: "sender moved to #{target} - no test asserts from/reply-to semantics"
    )
  end

  defp drop_mutation(node) do
    Mutation.new(node,
      variant: "delete",
      note: "reply_to removed - replies silently go to from; no test asserts the reply-to address"
    )
  end

  defp present([]), do: :skip
  defp present([_ | _] = mutations), do: mutations
end
