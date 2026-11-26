defmodule MutareSwooshIntegration.Mailer do
  use Swoosh.Mailer, otp_app: :mutare_swoosh_integration, adapter: Swoosh.Adapters.Test
end

defmodule MutareSwooshIntegration.SemanticsTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.{
    Attachment,
    Body,
    Deliver,
    Header,
    ProviderOption,
    Recipient,
    Sender,
    Subject
  }

  alias MutareSwooshIntegration.Mailer
  alias Swoosh.Email

  @email ~s'new(from: "sender@example.com", to: "reader@example.com")'

  test "field mutants still deliver and change only their intended fields" do
    from = {"", "sender@example.com"}
    to = {"", "reader@example.com"}
    reply_to = {"Support", "reply@example.com"}
    attachment = Swoosh.Attachment.new({:data, "invoice"}, filename: "invoice.txt")

    cases = [
      {Sender,
       ~s'new(from: "sender@example.com", to: "reader@example.com", reply_to: {"Support", "reply@example.com"})',
       [%{from: reply_to, reply_to: from}, %{reply_to: nil}]},
      {Recipient, @email, [%{to: [], cc: [to]}, %{to: [], bcc: [to]}, %{to: []}]},
      {Subject, @email <> ~s' |> subject("Welcome")', [%{subject: ""}]},
      {Body, @email <> ~s' |> html_body("<p>Welcome</p>")',
       [%{html_body: nil, text_body: "<p>Welcome</p>"}]},
      {Header, @email <> ~s' |> header("X-Tag", "welcome")', [%{headers: %{}}]},
      {Attachment,
       @email <>
         ~s' |> attachment(Swoosh.Attachment.new({:data, "invoice"}, filename: "invoice.txt", type: :inline))',
       [%{attachments: []}, %{attachments: [attachment]}]},
      {ProviderOption,
       ~s'new(from: "sender@example.com", to: "reader@example.com", provider_options: %{template_id: "tpl-1", tracking: true})',
       [%{provider_options: %{template_id: "tpl-1"}}, %{provider_options: %{tracking: true}}]}
    ]

    for {family, expression, changes} <- cases do
      source = """
      defmodule Message do
        import Swoosh.Email
        def build, do: #{expression}
      end
      """

      {[mod], sites} = compile_metamutant(source, [family])
      baseline = mod.build()
      assert_delivered(baseline)

      mutated =
        for site <- sites do
          email = with_active_mutant(site.id, fn -> mod.build() end)
          assert_delivered(email)
          email
        end

      expected = Enum.map(changes, &struct!(baseline, &1))
      assert Enum.sort(mutated) == Enum.sort(expected), inspect(family)
    end
  end

  test "a reply-to list passed through a variable can be removed and the email still delivers" do
    source = """
    defmodule Message do
      import Swoosh.Email
      def build(reply), do: #{@email} |> reply_to(reply)
    end
    """

    {[mod], [site]} = compile_metamutant(source, [Sender])
    baseline = mod.build(["first@example.com", "second@example.com"])
    assert_delivered(baseline)

    mutated =
      with_active_mutant(site.id, fn -> mod.build(["first@example.com", "second@example.com"]) end)

    assert mutated == %{baseline | reply_to: nil}
    assert_delivered(mutated)
  end

  test "the delivery mutant builds the email but the Swoosh test adapter receives nothing" do
    source = """
    defmodule Notification do
      alias MutareSwooshIntegration.Mailer
      def deliver(build), do: build.() |> Mailer.deliver()
    end
    """

    {[mod], [site]} = compile_metamutant(source, [{Deliver, mailer: Mailer}])
    email = Email.new(from: "sender@example.com", to: "reader@example.com")

    build = fn ->
      send(self(), :built)
      email
    end

    assert {:ok, %{}} == mod.deliver(build)
    assert_received :built
    assert_received {:email, ^email}

    assert with_active_mutant(site.id, fn -> mod.deliver(build) end) == {:ok, %{}}
    assert_received :built
    refute_received {:email, _}
  end

  defp assert_delivered(email) do
    assert {:ok, %{}} == Mailer.deliver(email)
    assert_received {:email, ^email}
  end
end
