defmodule Mutare.Swoosh.AttachmentTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.Attachment

  defp attachment_diffs(source), do: diffs_for(source, [Attachment], :swoosh_attachment)
  defp mutateds(source), do: attachment_diffs(source) |> Enum.map(&elem(&1, 1))

  defp mail(body), do: "defmodule Mail do\n  def build, do: #{body}\nend\n"

  defp import_mail(body),
    do: "defmodule Mail do\n  import Swoosh.Email\n  def build, do: #{body}\nend\n"

  test "swaps inline attachment disposition to attachment" do
    muts = mutateds(mail(~s'Swoosh.Attachment.new("qr.png", type: :inline)'))
    assert Enum.any?(muts, &(&1 =~ "type: :attachment"))
  end

  test "swaps inline attachment disposition when options are a map" do
    muts = mutateds(mail(~s'Swoosh.Attachment.new("qr.png", %{type: :inline})'))
    assert Enum.any?(muts, &(&1 =~ "%{type: :attachment}"))
  end

  test "swaps attachment disposition to inline" do
    muts = mutateds(mail(~s'Swoosh.Attachment.new("qr.png", type: :attachment)'))
    assert Enum.any?(muts, &(&1 =~ "type: :inline"))
  end

  test "does not mutate default disposition when no type option is exposed" do
    assert mutateds(mail(~s'Swoosh.Attachment.new("qr.png")')) == []
  end

  test "mutates nested attachment construction inside an email pipeline" do
    source = """
    defmodule Mail do
      import Swoosh.Email

      def build do
        new()
        |> attachment(Swoosh.Attachment.new("qr.png", type: :inline))
      end
    end
    """

    assert Enum.any?(mutateds(source), &(&1 =~ "type: :attachment"))
  end

  test "removes a direct attachment call by collapsing to the email" do
    muts = mutateds(mail(~s'Swoosh.Email.attachment(email, att)'))
    assert "email" in muts
  end

  test "removes a piped attachment stage via identity" do
    muts = mutateds(import_mail(~s'new() |> attachment(Swoosh.Attachment.new("qr.png"))'))
    assert "Elixir.Function.identity()" in muts
  end

  test "drops the attachment option from Swoosh.Email.new/1" do
    muts = mutateds(mail(~s'Swoosh.Email.new(to: "a@example.com", attachment: att)'))

    assert Enum.any?(muts, fn mut ->
             mut =~ ~s'to: "a@example.com"' and not String.contains?(mut, "attachment:")
           end)
  end

  test "does not match an attachments: option (not part of Swoosh.Email.new/1)" do
    assert mutateds(mail(~s'Swoosh.Email.new(attachments: [att])')) == []
  end

  test "declares variants and tags the removal with delete" do
    assert Attachment.variants() == ~w(inline attachment delete)

    result =
      Mutare.transform_string(mail(~s'Swoosh.Email.attachment(email, att)'),
        mutators: [Attachment]
      )

    delete = Enum.find(result.mutants, &(&1.variant == ["delete"]))

    assert delete.note =~ "no test asserts the attachment is present"
  end
end
