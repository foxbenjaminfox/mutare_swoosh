defmodule Mutare.Swoosh.BodyTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.Body

  defp body_diffs(source), do: diffs_for(source, [Body], :swoosh_body)
  defp mutateds(source), do: body_diffs(source) |> Enum.map(&elem(&1, 1))

  defp mail(body), do: "defmodule Mail do\n  import Swoosh.Email\n  def build, do: #{body}\nend\n"

  test "swaps html_body to text_body" do
    muts = mutateds(mail(~s'new() |> html_body("<p>Hello</p>")'))
    assert Enum.any?(muts, &(&1 =~ ~s'text_body("<p>Hello</p>")'))
  end

  test "swaps text_body to html_body" do
    muts = mutateds(mail(~s'new() |> text_body("Hello")'))
    assert Enum.any?(muts, &(&1 =~ ~s'html_body("Hello")'))
  end

  test "mutates Swoosh.Email.new/1 body option keys" do
    muts = mutateds(mail(~s'Swoosh.Email.new(html_body: "<p>Hello</p>")'))
    assert Enum.any?(muts, &(&1 =~ ~s'text_body: "<p>Hello</p>"'))
  end

  test "avoids duplicate body keys in map options" do
    muts = mutateds(mail(~s'Swoosh.Email.new(%{html_body: "<p>Hello</p>", text_body: "Hello"})'))
    assert muts == []
  end
end
