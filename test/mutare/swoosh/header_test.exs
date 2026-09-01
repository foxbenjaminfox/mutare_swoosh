defmodule Mutare.Swoosh.HeaderTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.Header

  defp header_diffs(source), do: diffs_for(source, [Header], :swoosh_header)
  defp mutateds(source), do: header_diffs(source) |> Enum.map(&elem(&1, 1))

  defp mail(body), do: "defmodule Mail do\n  def build, do: #{body}\nend\n"

  defp import_mail(body),
    do: "defmodule Mail do\n  import Swoosh.Email\n  def build, do: #{body}\nend\n"

  test "removes a direct header call by collapsing to the email" do
    muts = mutateds(mail(~s'Swoosh.Email.header(email, "X-Tag", "welcome")'))
    assert muts == ["email"]
  end

  test "removes a piped header stage via identity" do
    muts = mutateds(import_mail(~s'new() |> header("X-Tag", "welcome")'))
    assert muts == ["Elixir.Function.identity()"]
  end

  test "removes an aliased header call" do
    source = """
    defmodule Mail do
      alias Swoosh.Email

      def build(email), do: Email.header(email, "X-Tag", "welcome")
    end
    """

    assert mutateds(source) == ["email"]
  end

  test "drops one entry at a time from a literal headers: map in Swoosh.Email.new/1" do
    muts = mutateds(mail(~s'Swoosh.Email.new(headers: %{"X-A" => "1", "X-B" => "2"})'))

    assert Enum.any?(muts, &(&1 == ~s'Swoosh.Email.new(headers: %{"X-B" => "2"})'))
    assert Enum.any?(muts, &(&1 == ~s'Swoosh.Email.new(headers: %{"X-A" => "1"})'))
  end

  test "drops an opaque headers: value wholesale" do
    muts = mutateds(mail(~s'Swoosh.Email.new(to: "a@example.com", headers: build_headers())'))

    assert muts == [~s'Swoosh.Email.new(to: "a@example.com")']
  end

  test "produces nothing for an empty literal headers: value" do
    assert mutateds(mail(~s'Swoosh.Email.new(headers: %{})')) == []
  end

  test "does not match other modules or other arities" do
    assert mutateds(mail(~s'MyHeaders.header(email, "X-Tag", "welcome")')) == []
    assert mutateds(mail(~s'Swoosh.Email.header(email, "X-Tag")')) == []
  end

  test "declares the delete variant and tags produced mutants with it" do
    assert Header.variants() == ~w(delete)

    result =
      Mutare.transform_string(mail(~s'Swoosh.Email.header(email, "X-Tag", "welcome")'),
        mutators: [Header]
      )

    assert [site] = result.mutants
    assert site.variant == ["delete"]
    assert site.note =~ "no test asserts the header"
  end
end
