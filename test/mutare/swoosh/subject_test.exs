defmodule Mutare.Swoosh.SubjectTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.Subject

  defp subject_diffs(source), do: diffs_for(source, [Subject], :swoosh_subject)
  defp mutateds(source), do: subject_diffs(source) |> Enum.map(&elem(&1, 1))

  defp mail(body), do: "defmodule Mail do\n  import Swoosh.Email\n  def build, do: #{body}\nend\n"

  test "deletes a direct subject call by setting an empty subject" do
    muts = mutateds(mail(~s'new() |> subject("Welcome")'))
    assert Enum.any?(muts, &(&1 =~ ~s'subject("")'))
  end

  test "does not emit an equivalent direct empty-subject mutation" do
    assert mutateds(mail(~s'new() |> subject("")')) == []
  end

  test "deletes subject from Swoosh.Email.new/1 keyword options" do
    muts = mutateds(mail(~s'Swoosh.Email.new(to: "a@example.com", subject: "Welcome")'))

    assert Enum.any?(muts, fn mut ->
             mut =~ ~s'to: "a@example.com"' and not String.contains?(mut, "subject:")
           end)
  end

  test "deletes subject from Swoosh.Email.new/1 map options" do
    muts = mutateds(mail(~s'Swoosh.Email.new(%{to: "a@example.com", subject: "Welcome"})'))

    assert Enum.any?(muts, fn mut ->
             mut =~ ~s'to: "a@example.com"' and not String.contains?(mut, "subject:")
           end)
  end
end
