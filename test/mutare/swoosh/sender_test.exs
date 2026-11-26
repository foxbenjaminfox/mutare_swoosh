defmodule Mutare.Swoosh.SenderTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.Sender

  defp mutateds(source) do
    source
    |> diffs_for([Sender], :swoosh_sender)
    |> Enum.map(&elem(&1, 1))
  end

  defp mail(body) do
    """
    defmodule Mail do
      import Swoosh.Email
      def build(email, reply), do: #{body}
    end
    """
  end

  test "leaves a lone sender in place" do
    assert mutateds(mail(~s'email |> from("sender@example.com")')) == []
    assert mutateds(mail(~s'Swoosh.Email.from(email, "sender@example.com")')) == []
    assert mutateds(mail(~s'new(from: "sender@example.com")')) == []
  end

  test "drops direct and piped reply-to calls for scalars, literal lists and opaque values" do
    assert mutateds(mail(~s'Swoosh.Email.reply_to(email, "reply@example.com")')) == ["email"]
    assert mutateds(mail(~s'new() |> reply_to(["a@example.com", "b@example.com"])')) == ["new()"]
    assert mutateds(mail(~s'new() |> reply_to(reply)')) == ["new()"]
  end

  test "swaps two distinct mailboxes in keyword options and also drops reply-to" do
    source = mail(~s'new(from: {"Sender", "s@example.com"}, reply_to: "r@example.com")')

    assert mutateds(source) == [
             ~s'new(from: "r@example.com", reply_to: {"Sender", "s@example.com"})',
             ~s'new(from: {"Sender", "s@example.com"})'
           ]
  end

  test "swaps two single mailboxes in map options without renaming their keys" do
    source =
      mail(~s'Swoosh.Email.new(%{from: "s@example.com", reply_to: {nil, "r@example.com"}})')

    assert mutateds(source) == [
             ~s'Swoosh.Email.new(%{from: {nil, "r@example.com"}, reply_to: "s@example.com"})',
             ~s'Swoosh.Email.new(%{from: "s@example.com"})'
           ]
  end

  test "drops reply-to without swapping when a mailbox cannot be established" do
    for value <- [~s'["r@example.com"]', "reply", ~s'""', ~s'{"Name", ""}'] do
      source = mail(~s'new(from: "s@example.com", reply_to: #{value})')
      assert mutateds(source) == [~s'new(from: "s@example.com")']
    end
  end

  test "skips swaps with equivalent mailboxes or ambiguous option keys" do
    equivalent = mail(~s'new(from: "s@example.com", reply_to: {nil, "s@example.com"})')

    duplicate =
      mail(~s'new(from: "first@example.com", from: "s@example.com", reply_to: "r@example.com")')

    dynamic =
      mail(
        ~s'new(%{reply => "other@example.com", from: "s@example.com", reply_to: "r@example.com"})'
      )

    assert mutateds(equivalent) == [~s'new(from: "s@example.com")']
    assert mutateds(duplicate) == [~s'new(from: "first@example.com", from: "s@example.com")']
    assert mutateds(dynamic) == [~s'new(%{reply => "other@example.com", from: "s@example.com"})']
  end

  test "keeps both ignore labels for the swap and the delete label for removal" do
    assert Sender.variants() == ~w(from reply_to delete)
    source = mail(~s'new(from: "s@example.com", reply_to: "r@example.com")')
    result = Mutare.transform_string(source, mutators: [Sender])

    assert [swap, drop] = result.mutants
    assert Enum.sort(swap.variant) == ~w(from reply_to)
    assert drop.variant == ["delete"]
    assert drop.note =~ "replies silently go to from"
  end
end
