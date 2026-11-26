defmodule Mutare.Swoosh.Sender do
  @moduledoc """
  :swoosh_sender swaps the sender and reply-to mailboxes in literal Swoosh.Email.new/1 options
  and removes reply-to settings.

  A swap requires one `:from` and one `:reply_to` option, each holding a recognizable single
  mailbox. Both options remain present, so Swoosh can still deliver the email. The swap carries
  both the `from` and `reply_to` ignore labels.

  The `delete` variant removes a `reply_to(email, value)` call or a `:reply_to` option.
  With no reply-to address left, replies go to `from`.
  """

  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @impl Mutare.Mutator
  def name, do: :swoosh_sender

  @impl Mutare.Mutator
  def variants, do: ~w(from reply_to delete)

  @impl Mutare.Mutator
  def mutate(node) do
    case Calls.resolved_call_to(node, Swoosh.Email, [:reply_to, :new]) do
      {:ok, :reply_to, [email, _value], _rebuild} -> [drop_mutation(email)]
      {:ok, :new, [opts], rebuild} -> new_option_mutations(opts, rebuild)
      _ -> :skip
    end
  end

  defp new_option_mutations(opts, rebuild) do
    case SAST.opts_container(opts) do
      {:ok, {_kind, entries, wrap}} ->
        rebuild_new = fn new_entries -> rebuild.(:new, [wrap.(new_entries)]) end

        indexed = Enum.with_index(entries)
        by_key = Enum.group_by(indexed, fn {entry, _index} -> SAST.key(entry) end)

        drops =
          for {_entry, index} <- Map.get(by_key, :reply_to, []) do
            entries |> List.delete_at(index) |> rebuild_new.() |> drop_mutation()
          end

        case swap_mutation(by_key, entries, rebuild_new) ++ drops do
          [] -> :skip
          mutations -> mutations
        end

      :error ->
        :skip
    end
  end

  defp swap_mutation(by_key, entries, rebuild) do
    with %{
           from: [{{_from_key, from_value} = from_entry, from_index}],
           reply_to: [{{_reply_key, reply_value} = reply_entry, reply_index}]
         } <- by_key,
         false <- Map.has_key?(by_key, nil),
         {:ok, from} <- mailbox(AST.unwrap_literal(from_value)),
         {:ok, reply_to} when reply_to != from <- mailbox(AST.unwrap_literal(reply_value)) do
      swapped =
        entries
        |> List.replace_at(from_index, SAST.replace_value(from_entry, reply_value))
        |> List.replace_at(reply_index, SAST.replace_value(reply_entry, from_value))

      [
        Mutation.new(rebuild.(swapped),
          variant: [:from, :reply_to],
          note: "sender and reply-to exchanged - no test detected the mailbox swap"
        )
      ]
    else
      _ -> []
    end
  end

  defp mailbox(address) when is_binary(address) and address != "", do: {:ok, {"", address}}

  defp mailbox({name, address}) do
    with name when is_binary(name) or is_nil(name) <- AST.unwrap_literal(name),
         address when is_binary(address) and address != "" <- AST.unwrap_literal(address) do
      {:ok, {name || "", address}}
    else
      _ -> :error
    end
  end

  defp mailbox(_value), do: :error

  defp drop_mutation(node) do
    Mutation.new(node,
      variant: "delete",
      note: "reply_to removed - replies silently go to from; no test asserts the reply-to address"
    )
  end
end
