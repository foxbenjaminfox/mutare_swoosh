defmodule Mutare.Swoosh.Body do
  @moduledoc """
  :swoosh_body swaps Swoosh body parts, html_body and text_body.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @fields ~w(html_body text_body)a

  @impl Mutare.Mutator
  def name, do: :swoosh_body

  @impl Mutare.Mutator
  def variants, do: ~w(html_body text_body)

  @impl Mutare.Mutator
  def mutate(node, %{pipe_mode: pipe_mode}) do
    (call_mutations(node, pipe_mode) ++ new_option_mutations(node, pipe_mode)) |> present()
  end

  defp call_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Email, @fields) do
      {:ok, fun, args, rebuild} ->
        case SAST.value_arg(args, pipe_mode) do
          {_index, _value} ->
            target = target(fun)
            [mutation(rebuild.(target, args), target)]

          nil ->
            []
        end

      :error ->
        []
    end
  end

  defp new_option_mutations(node, pipe_mode) do
    case Calls.resolved_call_to(node, Swoosh.Email, :new) do
      {:ok, :new, args, rebuild} ->
        case SAST.new_opts_arg(args, pipe_mode) do
          {arg_index, {kind, entries, wrap}} ->
            entries
            |> Enum.with_index()
            |> Enum.flat_map(fn {entry, entry_index} ->
              with key when key in @fields <- SAST.key(entry),
                   target <- target(key),
                   true <- SAST.unique_key?(kind, entries, target) do
                mutated_entries =
                  List.replace_at(entries, entry_index, SAST.replace_key(entry, target))

                [
                  mutation(
                    rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries))),
                    target
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

  defp target(:html_body), do: :text_body
  defp target(:text_body), do: :html_body

  defp mutation(node, target) do
    Mutation.new(node,
      variant: target,
      note: "body moved to #{target} - no test asserts the body part"
    )
  end

  defp present([]), do: :skip
  defp present([_ | _] = mutations), do: mutations
end
