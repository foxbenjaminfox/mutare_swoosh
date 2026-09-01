defmodule Mutare.Swoosh.AST do
  @moduledoc false

  alias Mutare.AST
  alias Mutare.Mutator

  @type container :: {:keyword | :map, [Macro.t()], ([Macro.t()] -> Macro.t())}

  @spec value_arg([Macro.t()], Mutator.pipe_mode()) :: {non_neg_integer(), Macro.t()} | nil
  def value_arg(args, pipe_mode), do: effective_arg(args, pipe_mode, 2, 1)

  @spec new_opts_arg([Macro.t()], Mutator.pipe_mode()) ::
          {non_neg_integer(), container()} | nil
  def new_opts_arg(args, pipe_mode) do
    with {index, opts} <- effective_arg(args, pipe_mode, 1, 0),
         {:ok, container} <- opts_container(opts) do
      {index, container}
    else
      _ -> nil
    end
  end

  @spec effective_arg([Macro.t()], Mutator.pipe_mode(), non_neg_integer(), non_neg_integer()) ::
          {non_neg_integer(), Macro.t()} | nil
  def effective_arg(args, pipe_mode, arity, effective_index) do
    with ^arity <- Mutator.effective_arity(args, pipe_mode),
         index when is_integer(index) <- Mutator.visible_index(effective_index, pipe_mode),
         value when not is_nil(value) <- Enum.at(args, index) do
      {index, value}
    else
      _ -> nil
    end
  end

  @spec opts_container(Macro.t()) :: {:ok, container()} | :error
  def opts_container(node) do
    case keyword_container(node) do
      {:ok, entries, wrap} -> {:ok, {:keyword, entries, wrap}}
      :error -> map_container(node)
    end
  end

  @spec keyword_container(Macro.t()) ::
          {:ok, [Macro.t()], ([Macro.t()] -> Macro.t())} | :error
  def keyword_container(node) do
    with {:ok, entries, wrap} <- list_container(node),
         true <- keyword_entries?(entries) do
      {:ok, entries, wrap}
    else
      _ -> :error
    end
  end

  @spec map_container(Macro.t()) :: {:ok, container()} | :error
  def map_container({:%{}, meta, entries}) when is_list(entries) do
    if Enum.all?(entries, &pair?/1) do
      {:ok, {:map, entries, fn new_entries -> {:%{}, meta, new_entries} end}}
    else
      :error
    end
  end

  def map_container(_node), do: :error

  @spec list_container(Macro.t()) ::
          {:ok, [Macro.t()], ([Macro.t()] -> Macro.t())} | :error
  def list_container({:__block__, meta, [items]}) when is_list(items),
    do: {:ok, items, fn new_items -> {:__block__, meta, [new_items]} end}

  def list_container(items) when is_list(items), do: {:ok, items, & &1}
  def list_container(_node), do: :error

  @spec recipient_deletions(Macro.t()) :: [Macro.t()]
  def recipient_deletions(node) do
    case list_container(node) do
      {:ok, [], _wrap} ->
        []

      {:ok, items, wrap} ->
        for index <- 0..(length(items) - 1), do: wrap.(List.delete_at(items, index))

      :error ->
        [empty_list()]
    end
  end

  @spec literal_atom(Macro.t()) :: atom() | nil
  def literal_atom(node) do
    case AST.literal_value(node) do
      {:ok, atom} when is_atom(atom) -> atom
      _ -> nil
    end
  end

  @spec literal_value(Macro.t()) :: {:ok, term()} | :error
  def literal_value(node), do: AST.literal_value(node)

  @spec key(Macro.t()) :: atom() | nil
  def key({key, _value}), do: AST.key_atom(key)
  def key(_entry), do: nil

  @spec pair?(Macro.t()) :: boolean()
  def pair?({_key, _value}), do: true
  def pair?(_entry), do: false

  @spec replace_key(Macro.t(), atom()) :: Macro.t()
  def replace_key({key, value}, new_key), do: {replace_atom(key, new_key), value}

  @spec replace_value(Macro.t(), Macro.t()) :: Macro.t()
  def replace_value({key, _value}, new_value), do: {key, new_value}

  # Rebuilt with fresh metadata (the `Mutare.AST.literal/1` clean-meta rule); only the
  # `format: :keyword` marker survives, so a swapped keyword key still renders as `key:`.
  @spec replace_atom(Macro.t(), atom()) :: Macro.t()
  def replace_atom({:__block__, meta, [_old]}, new) do
    if Keyword.get(meta, :format) == :keyword, do: AST.keyword_key(new), else: AST.literal(new)
  end

  def replace_atom(_old, new), do: AST.literal(new)

  @spec has_key?([Macro.t()], atom()) :: boolean()
  def has_key?(entries, wanted), do: Enum.any?(entries, &(key(&1) == wanted))

  @spec unique_key?(:keyword | :map, [Macro.t()], atom()) :: boolean()
  def unique_key?(:keyword, _entries, _key), do: true
  def unique_key?(:map, entries, key), do: not has_key?(entries, key)

  @spec empty_string() :: Macro.t()
  def empty_string, do: AST.literal("")

  @spec empty_list() :: Macro.t()
  def empty_list, do: AST.literal([])

  @spec empty_list?(Macro.t()) :: boolean()
  def empty_list?(node) do
    case list_container(node) do
      {:ok, [], _wrap} -> true
      _ -> false
    end
  end

  # The pipe-aware "remove this call, keep the email" replacement: a direct call collapses to
  # its first argument; a piped stage becomes `Elixir.Function.identity()` (absolute, so no
  # alias in the target source can redirect it).
  @spec collapse_to_email([Macro.t()], Mutator.pipe_mode()) :: Macro.t() | nil
  def collapse_to_email(_args, :piped), do: AST.absolute_call([:Function], :identity, [])
  def collapse_to_email([email | _rest], :unpiped), do: email
  def collapse_to_email([], :unpiped), do: nil

  # The pipe-aware "replace this call with a constant" replacement: a direct call becomes the
  # value; a piped stage becomes `Elixir.Kernel.then(fn _ -> value end)` so the pipe stays legal
  # and its left side is still evaluated.
  @spec constant_stage(Macro.t(), Mutator.pipe_mode()) :: Macro.t()
  def constant_stage(value, :unpiped), do: value

  def constant_stage(value, :piped) do
    ignore_arg = {:fn, [], [{:->, [], [[{:_, [], nil}], value]}]}
    AST.absolute_call([:Kernel], :then, [ignore_arg])
  end

  # `{:ok, %{}}` — a literal 2-tuple node of clean-meta quoted forms.
  @spec ok_empty_map() :: Macro.t()
  def ok_empty_map, do: {AST.literal(:ok), empty_map()}

  @spec empty_map() :: Macro.t()
  def empty_map, do: {:%{}, [], []}

  defp keyword_entries?([]), do: true

  defp keyword_entries?(entries),
    do: Enum.all?(entries, fn entry -> pair?(entry) and key(entry) != nil end)
end
