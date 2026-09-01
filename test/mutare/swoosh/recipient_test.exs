defmodule Mutare.Swoosh.RecipientTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.Recipient

  defp recipient_diffs(source), do: diffs_for(source, [Recipient], :swoosh_recipient)
  defp mutateds(source), do: recipient_diffs(source) |> Enum.map(&elem(&1, 1))

  defp mail(body) do
    """
    defmodule Mail do
      import Swoosh.Email

      def build(user) do
        #{body}
      end
    end
    """
  end

  test "swaps to, cc, and bcc recipient classes on imported calls" do
    muts = mutateds(mail(~s'new() |> to("a@example.com")'))

    assert Enum.any?(muts, &(&1 =~ ~s'cc("a@example.com")'))
    assert Enum.any?(muts, &(&1 =~ ~s'bcc("a@example.com")'))
  end

  test "swaps put_to, put_cc, and put_bcc recipient classes" do
    muts = mutateds(mail(~s'new() |> put_to("a@example.com")'))

    assert Enum.any?(muts, &(&1 =~ ~s'put_cc("a@example.com")'))
    assert Enum.any?(muts, &(&1 =~ ~s'put_bcc("a@example.com")'))
  end

  test "weakens put-style calls to their append-style sibling" do
    assert Enum.any?(mutateds(mail(~s'new() |> put_to("a@example.com")')), fn mut ->
             mut =~ ~s'to("a@example.com")' and not String.contains?(mut, "put_")
           end)

    assert Enum.any?(mutateds(mail(~s'new() |> put_cc("a@example.com")')), fn mut ->
             mut =~ ~s'cc("a@example.com")' and not String.contains?(mut, "put_")
           end)

    assert Enum.any?(mutateds(mail(~s'new() |> put_bcc("a@example.com")')), fn mut ->
             mut =~ ~s'bcc("a@example.com")' and not String.contains?(mut, "put_")
           end)
  end

  test "does not swap append-style calls to put-style (one-directional)" do
    refute Enum.any?(mutateds(mail(~s'new() |> to("a@example.com")')), &(&1 =~ "put_"))
  end

  test "the append swap carries the pre-existing-recipients equivalence note" do
    result =
      Mutare.transform_string(mail(~s'new() |> put_to("a@example.com")'), mutators: [Recipient])

    append = Enum.find(result.mutants, &(&1.variant == ["append"]))

    assert append.note =~ "a kill may require pre-existing recipients"
  end

  test "deletes one recipient from a literal list" do
    muts = mutateds(mail(~s'new() |> to(["a@example.com", "b@example.com"])'))

    assert Enum.any?(muts, &(&1 =~ ~s'to(["b@example.com"])'))
    assert Enum.any?(muts, &(&1 =~ ~s'to(["a@example.com"])'))
  end

  test "deletes a scalar recipient by replacing it with an empty list" do
    assert Enum.any?(mutateds(mail(~s'new() |> cc("a@example.com")')), &(&1 =~ "cc([])"))
  end

  test "deletes the recipient argument, not an equal email argument" do
    muts = mutateds(mail(~s'Swoosh.Email.to(user, user)'))

    assert Enum.any?(muts, &(&1 =~ "Swoosh.Email.to(user, [])"))
    refute Enum.any?(muts, &(&1 =~ "Swoosh.Email.to([], user)"))
  end

  test "produces nothing for a statically empty append-style recipient list" do
    assert mutateds(mail(~s'new() |> to([])')) == []
    assert mutateds(mail(~s'Swoosh.Email.new(to: [])')) == []
  end

  test "keeps put-style swaps for an empty list (clearing a different class is observable)" do
    muts = mutateds(mail(~s'new() |> put_to([])'))

    assert Enum.any?(muts, &(&1 =~ "put_cc([])"))
    assert Enum.any?(muts, &(&1 =~ "put_bcc([])"))
  end

  test "mutates Swoosh.Email.new/1 recipient option keys and values" do
    muts = mutateds(mail(~s'Swoosh.Email.new(to: ["a@example.com", "b@example.com"])'))

    assert Enum.any?(muts, &(&1 =~ ~s'cc: ["a@example.com", "b@example.com"]'))
    assert Enum.any?(muts, &(&1 =~ ~s'bcc: ["a@example.com", "b@example.com"]'))
    assert Enum.any?(muts, &(&1 =~ ~s'to: ["b@example.com"]'))
    assert Enum.any?(muts, &(&1 =~ ~s'to: ["a@example.com"]'))
  end

  test "avoids duplicate keys when mutating map options" do
    muts = mutateds(mail(~s'Swoosh.Email.new(%{to: "a@example.com", cc: "c@example.com"})'))

    refute Enum.any?(muts, &(&1 =~ ~s'%{cc: "a@example.com"'))
    assert Enum.any?(muts, &(&1 =~ ~s'bcc: "a@example.com"'))
  end

  test "declares variants and tags produced mutants" do
    assert Recipient.variants() == ~w(to cc bcc delete append)

    result =
      Mutare.transform_string(mail(~s'new() |> to("a@example.com")'), mutators: [Recipient])

    variants = result.mutants |> Enum.flat_map(& &1.variant) |> Enum.sort()

    assert variants == ["bcc", "cc", "delete"]

    put_result =
      Mutare.transform_string(mail(~s'new() |> put_to("a@example.com")'), mutators: [Recipient])

    put_variants = put_result.mutants |> Enum.flat_map(& &1.variant) |> Enum.sort()

    assert put_variants == ["append", "bcc", "cc", "delete"]
  end
end
