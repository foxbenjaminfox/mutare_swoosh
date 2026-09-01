defmodule Mutare.SwooshTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Mutator.Dispatch

  doctest Mutare.Swoosh

  test "all/0 lists every Swoosh family in report order" do
    assert Mutare.Swoosh.all() == [
             Mutare.Swoosh.Recipient,
             Mutare.Swoosh.Sender,
             Mutare.Swoosh.Body,
             Mutare.Swoosh.Subject,
             Mutare.Swoosh.Attachment,
             Mutare.Swoosh.Header,
             Mutare.Swoosh.ProviderOption,
             Mutare.Swoosh.Deliver
           ]
  end

  test "all/1 configures the deliver family in place" do
    configured = Mutare.Swoosh.all(mailer: MyApp.Mailer)

    assert {Mutare.Swoosh.Deliver, mailer: MyApp.Mailer} in configured
    assert Enum.map(configured, &family_module/1) == Mutare.Swoosh.all()

    assert_raise ArgumentError, fn -> Mutare.Swoosh.all(mail: MyApp.Mailer) end
  end

  test "every family resolves as a Mutare mutator" do
    for module <- Mutare.Swoosh.all() do
      assert Dispatch.implemented_by?(module)
    end
  end

  test "integration surface records all Swoosh family names and compiles" do
    source = """
    defmodule MailerExample do
      import Swoosh.Email

      def welcome(user, qr) do
        new()
        |> from("noreply@example.com")
        |> reply_to("support@example.com")
        |> to([user.email, "audit@example.com"])
        |> subject("Welcome")
        |> html_body("<p>Hello</p>")
        |> header("X-Campaign", "welcome")
        |> put_provider_option(:template_id, "tpl-1")
        |> attachment(Swoosh.Attachment.new({:data, qr}, type: :inline, filename: "qr.png"))
        |> Mutare.SwooshTest.Mailer.deliver()
      end
    end
    """

    mutators = Mutare.Swoosh.all(mailer: Mutare.SwooshTest.Mailer)

    names =
      source
      |> diffs(mutators)
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()
      |> Enum.sort()

    assert names == [
             :swoosh_attachment,
             :swoosh_body,
             :swoosh_deliver,
             :swoosh_header,
             :swoosh_provider_option,
             :swoosh_recipient,
             :swoosh_sender,
             :swoosh_subject
           ]

    assert_metamutant_compiles(source, mutators)
  end

  defp family_module({module, _opts}), do: module
  defp family_module(module), do: module
end
