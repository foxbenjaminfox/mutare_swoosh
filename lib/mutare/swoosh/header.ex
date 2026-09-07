defmodule Mutare.Swoosh.Header do
  @moduledoc """
  :swoosh_header removes custom email headers.

  A `Swoosh.Email.header(email, name, value)` call collapses to the email (piped stages become
  identity). In Swoosh.Email.new/1, a `headers:` option with a literal map (or keyword) value has
  one entry dropped per mutant; an opaque value (a variable, a call) drops the whole `headers:`
  option instead. An empty literal `headers:` value produces no mutations — removing nothing is a
  no-op.

  A survivor means no test asserts the header — precisely the tracking, list-management, and
  provider-routing headers that are set and never checked.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation
  alias Mutare.Swoosh.AST, as: SAST

  @impl Mutare.Mutator
  def name, do: :swoosh_header

  @impl Mutare.Mutator
  def variants, do: ~w(delete)

  @impl Mutare.Mutator
  def mutate(node, %{pipe_mode: pipe_mode}) do
    (call_mutations(node, pipe_mode) ++ new_option_mutations(node, pipe_mode)) |> present()
  end

  defp call_mutations(node, pipe_mode) do
    with {:ok, :header, args, _rebuild} <- Calls.resolved_call_to(node, Swoosh.Email, :header),
         3 <- Mutator.effective_arity(args, pipe_mode),
         collapsed when not is_nil(collapsed) <- SAST.collapse_to_email(args, pipe_mode) do
      [mutation(collapsed)]
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
              if SAST.key(entry) == :headers do
                headers_mutations(entry, entries, entry_index, wrap, args, arg_index, rebuild)
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

  # A literal headers container loses one entry per mutant; an opaque value loses the whole
  # `headers:` option. An empty literal container yields nothing (an equivalent mutant). Every
  # entry is a `{key, value}` pair — both container readers (`SAST.keyword_container/1`,
  # `SAST.map_container/1`) admit nothing else — so this is the only clause.
  defp headers_mutations(
         {_key, value} = entry,
         entries,
         entry_index,
         wrap,
         args,
         arg_index,
         rebuild
       ) do
    case SAST.opts_container(value) do
      {:ok, {_kind, [], _header_wrap}} ->
        []

      {:ok, {_kind, header_entries, header_wrap}} ->
        for index <- 0..(length(header_entries) - 1) do
          deleted = header_wrap.(List.delete_at(header_entries, index))

          mutated_entries =
            List.replace_at(entries, entry_index, SAST.replace_value(entry, deleted))

          mutation(rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries))))
        end

      :error ->
        mutated_entries = List.delete_at(entries, entry_index)
        [mutation(rebuild.(:new, List.replace_at(args, arg_index, wrap.(mutated_entries))))]
    end
  end

  defp mutation(node) do
    Mutation.new(node,
      variant: "delete",
      note: "header removed - no test asserts the header"
    )
  end

  defp present([]), do: :skip
  defp present([_ | _] = mutations), do: mutations
end
