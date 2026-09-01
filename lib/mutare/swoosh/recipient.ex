defmodule Mutare.Swoosh.Recipient do
  @moduledoc """
  :swoosh_recipient mutates Swoosh recipient semantics.

  The family swaps recipient classes to, cc, and bcc for both append-style calls and put-style
  calls. It also deletes one recipient from recipient values, and weakens each put-style call to
  its append-style sibling (`put_to` becomes `to`, and likewise for cc and bcc). The class swaps
  and deletions also apply inside Swoosh.Email.new/1 options.

  The put-to-append swap is deliberately one-directional: writing `put_to` declares interest in
  replacement semantics, which a test should pin, while a plain `to` declares no such intent, so
  no reverse swap is minted. The swap is equivalent when the recipient list is empty at that
  point, and its report note says a kill may require pre-existing recipients.

  A statically empty recipient list on an append-style call (`to([])`) produces no mutations:
  appending nothing is a no-op for every class, so both the class swaps and the deletion would be
  equivalent mutants. Put-style calls keep their swaps (clearing a different class is
  observable).

  Deleting a single-element literal list (`to(["a"])` becoming `to([])`) produces the same
  program as the core `:list` family's collapse of that list; when both run, the mutant is minted
  twice.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @add_fields ~w(to cc bcc)a
  @put_fields ~w(put_to put_cc put_bcc)a
  @field_targets %{
    to: [:cc, :bcc],
    cc: [:to, :bcc],
    bcc: [:to, :cc],
    put_to: [:put_cc, :put_bcc],
    put_cc: [:put_to, :put_bcc],
    put_bcc: [:put_to, :put_cc]
  }
  @append_targets %{put_to: :to, put_cc: :cc, put_bcc: :bcc}

  @impl Mutare.Mutator
  def name, do: :swoosh_recipient

  @impl Mutare.Mutator
  def variants, do: ~w(to cc bcc delete append)

  @impl Mutare.Mutator
  def mutate(node, %{pipe_mode: pipe_mode}) do
    (call_mutations(node, pipe_mode) ++ new_option_mutations(node, pipe_mode)) |> present()
  end

  defp call_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Email, @add_fields ++ @put_fields) do
      {:ok, fun, args, rebuild} ->
        with {index, recipients} <- SAST.value_arg(args, pipe_mode),
             false <- fun in @add_fields and SAST.empty_list?(recipients) do
          class_swaps(fun, args, rebuild) ++
            append_swaps(fun, args, rebuild) ++
            recipient_deletes(fun, args, rebuild, index, recipients)
        else
          _ -> []
        end

      :error ->
        []
    end
  end

  defp class_swaps(fun, args, rebuild) do
    for target <- Map.fetch!(@field_targets, fun) do
      field = base_field(target)

      Mutation.new(rebuild.(target, args),
        variant: field,
        note: "recipient moved to #{field} - no test asserts the recipient class"
      )
    end
  end

  defp append_swaps(fun, args, rebuild) when fun in @put_fields do
    target = Map.fetch!(@append_targets, fun)

    [
      Mutation.new(rebuild.(target, args),
        variant: "append",
        note:
          "#{fun} weakened to #{target} (replace became append) - equivalent when no " <>
            "#{target} recipients are set yet, so a kill may require pre-existing recipients"
      )
    ]
  end

  defp append_swaps(_fun, _args, _rebuild), do: []

  defp recipient_deletes(fun, args, rebuild, index, recipients) do
    for deleted <- SAST.recipient_deletions(recipients) do
      Mutation.new(rebuild.(fun, List.replace_at(args, index, deleted)),
        variant: "delete",
        note: "recipient deleted - no test asserts every recipient"
      )
    end
  end

  defp new_option_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Email, :new) do
      {:ok, :new, args, rebuild} ->
        case SAST.new_opts_arg(args, pipe_mode) do
          {index, {kind, entries, wrap}} ->
            option_key_swaps(kind, entries, wrap, args, index, rebuild) ++
              option_recipient_deletes(entries, wrap, args, index, rebuild)

          nil ->
            []
        end

      :error ->
        []
    end
  end

  defp option_key_swaps(kind, entries, wrap, args, arg_index, rebuild) do
    entries
    |> Enum.with_index()
    |> Enum.flat_map(fn {entry, entry_index} ->
      case SAST.key(entry) do
        key when key in @add_fields ->
          with {_key, value} <- entry,
               false <- SAST.empty_list?(value) do
            for target <- @field_targets[key],
                SAST.unique_key?(kind, entries, target) do
              mutated_entries =
                List.replace_at(entries, entry_index, SAST.replace_key(entry, target))

              Mutation.new(
                rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries))),
                variant: target,
                note: "recipient moved to #{target} - no test asserts the recipient class"
              )
            end
          else
            _ -> []
          end

        _other ->
          []
      end
    end)
  end

  defp option_recipient_deletes(entries, wrap, args, arg_index, rebuild) do
    entries
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {{_key, recipients} = entry, entry_index} ->
        if SAST.key(entry) in @add_fields do
          for deleted <- SAST.recipient_deletions(recipients) do
            mutated_entries =
              List.replace_at(entries, entry_index, SAST.replace_value(entry, deleted))

            Mutation.new(rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries))),
              variant: "delete",
              note: "recipient deleted - no test asserts every recipient"
            )
          end
        else
          []
        end

      _other ->
        []
    end)
  end

  defp base_field(:put_to), do: "to"
  defp base_field(:put_cc), do: "cc"
  defp base_field(:put_bcc), do: "bcc"
  defp base_field(field) when field in @add_fields, do: Atom.to_string(field)

  defp present([]), do: :skip
  defp present([_ | _] = mutations), do: mutations
end
