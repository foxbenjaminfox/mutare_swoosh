defmodule Mutare.Swoosh.SenderTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.Sender

  defp sender_diffs(source), do: diffs_for(source, [Sender], :swoosh_sender)
  defp mutateds(source), do: sender_diffs(source) |> Enum.map(&elem(&1, 1))

  defp mail(body), do: "defmodule Mail do\n  import Swoosh.Email\n  def build, do: #{body}\nend\n"

  test "swaps from to reply_to" do
    muts = mutateds(mail(~s'new() |> from("sender@example.com")'))
    assert Enum.any?(muts, &(&1 =~ ~s'reply_to("sender@example.com")'))
  end

  test "swaps scalar reply_to to from" do
    muts = mutateds(mail(~s'new() |> reply_to("reply@example.com")'))
    assert Enum.any?(muts, &(&1 =~ ~s'from("reply@example.com")'))
  end

  test "does not turn a literal reply_to list into from, but still drops it" do
    muts = mutateds(mail(~s'new() |> reply_to(["a@example.com", "b@example.com"])'))

    refute Enum.any?(muts, &(&1 =~ "from("))
    assert muts == ["Elixir.Function.identity()"]
  end

  test "drops a direct reply_to call by collapsing to the email" do
    muts = mutateds(mail(~s'Swoosh.Email.reply_to(email, "reply@example.com")'))
    assert "email" in muts
  end

  test "drops a piped reply_to stage via identity" do
    muts = mutateds(mail(~s'new() |> reply_to("reply@example.com")'))
    assert "Elixir.Function.identity()" in muts
  end

  test "does not drop from" do
    muts = mutateds(mail(~s'Swoosh.Email.from(email, "sender@example.com")'))

    refute "email" in muts
    refute Enum.any?(muts, &(&1 =~ "identity"))
  end

  test "mutates Swoosh.Email.new/1 sender option keys" do
    muts = mutateds(mail(~s'Swoosh.Email.new(from: "sender@example.com")'))
    assert Enum.any?(muts, &(&1 =~ ~s'reply_to: "sender@example.com"'))
  end

  test "drops the reply_to option from Swoosh.Email.new/1" do
    muts = mutateds(mail(~s'Swoosh.Email.new(from: "s@example.com", reply_to: "r@example.com")'))

    assert Enum.any?(muts, fn mut ->
             mut =~ ~s'from: "s@example.com"' and not String.contains?(mut, "reply_to:")
           end)
  end

  test "does not drop the from option from Swoosh.Email.new/1" do
    muts = mutateds(mail(~s'Swoosh.Email.new(from: "s@example.com")'))
    refute Enum.any?(muts, &(&1 == "Swoosh.Email.new([])"))
  end

  test "avoids duplicate sender keys in map options but still drops reply_to" do
    muts =
      mutateds(
        mail(~s'Swoosh.Email.new(%{from: "sender@example.com", reply_to: "r@example.com"})')
      )

    assert muts == [~s'Swoosh.Email.new(%{from: "sender@example.com"})']
  end

  test "declares variants and tags the drop mutants with delete" do
    assert Sender.variants() == ~w(from reply_to delete)

    result =
      Mutare.transform_string(mail(~s'new() |> reply_to("r@example.com")'), mutators: [Sender])

    drop = Enum.find(result.mutants, &(&1.variant == ["delete"]))

    assert drop.note =~ "replies silently go to from"
  end
end
