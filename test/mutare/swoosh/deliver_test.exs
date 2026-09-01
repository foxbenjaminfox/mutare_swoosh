defmodule Mutare.Swoosh.DeliverTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.Deliver
  alias Mutare.SwooshTest.Mailer

  defp deliver_diffs(source, config),
    do: diffs_for(source, [{Deliver, config}], :swoosh_deliver)

  defp mutateds(source, config \\ [mailer: Mailer]),
    do: deliver_diffs(source, config) |> Enum.map(&elem(&1, 1))

  defp mail(body), do: "defmodule Notifier do\n  def send_welcome(email), do: #{body}\nend\n"

  test "replaces a direct deliver call with {:ok, %{}}" do
    assert mutateds(mail("Mutare.SwooshTest.Mailer.deliver(email)")) == ["{:ok, %{}}"]
  end

  test "replaces a direct deliver/2 call with {:ok, %{}}" do
    assert mutateds(mail("Mutare.SwooshTest.Mailer.deliver(email, retries: 0)")) ==
             ["{:ok, %{}}"]
  end

  test "replaces an aliased deliver call" do
    source = """
    defmodule Notifier do
      alias Mutare.SwooshTest.Mailer

      def send_welcome(email), do: Mailer.deliver(email)
    end
    """

    assert mutateds(source) == ["{:ok, %{}}"]
  end

  test "replaces a piped deliver stage while keeping the email evaluated" do
    source = """
    defmodule Notifier do
      alias Mutare.SwooshTest.Mailer

      def send_welcome(email) do
        email
        |> Mailer.deliver()
      end
    end
    """

    assert mutateds(source) == ["Elixir.Kernel.then(fn _ -> {:ok, %{}} end)"]
  end

  test "replaces deliver! with %{}" do
    assert mutateds(mail("Mutare.SwooshTest.Mailer.deliver!(email)")) == ["%{}"]
  end

  test "replaces a piped deliver! stage with a %{} constant stage" do
    source = """
    defmodule Notifier do
      alias Mutare.SwooshTest.Mailer

      def send_welcome(email), do: email |> Mailer.deliver!()
    end
    """

    assert mutateds(source) == ["Elixir.Kernel.then(fn _ -> %{} end)"]
  end

  test "accepts a list of mailers" do
    source = mail("Mutare.SwooshTest.Mailer.deliver(email)")
    assert mutateds(source, mailer: [OtherMailer, Mailer]) == ["{:ok, %{}}"]
  end

  test "produces nothing without a configured mailer" do
    source = mail("Mutare.SwooshTest.Mailer.deliver(email)")

    assert diffs_for(source, [Deliver], :swoosh_deliver) == []
    assert mutateds(source, []) == []
  end

  test "does not match other modules, other functions, or other arities" do
    assert mutateds(mail("Other.deliver(email)")) == []
    assert mutateds(mail("Mutare.SwooshTest.Mailer.deliver_many(emails)")) == []
    assert mutateds(mail("Mutare.SwooshTest.Mailer.deliver(email, config, extra)")) == []
  end

  test "the metamutant with a piped deliver compiles" do
    source = """
    defmodule Notifier do
      alias Mutare.SwooshTest.Mailer

      def send_welcome(email) do
        email
        |> Mailer.deliver()
      end
    end
    """

    assert_metamutant_compiles(source, [{Deliver, mailer: Mailer}])
  end

  test "init/1 rejects malformed configuration at startup" do
    assert_raise ArgumentError, fn -> Deliver.init(mailer: "MyApp.Mailer") end
    assert_raise ArgumentError, fn -> Deliver.init(mailers: Mailer) end
  end

  test "declares variants and tags each mutant with the replaced function" do
    assert Deliver.variants() == ~w(deliver deliver!)

    result =
      Mutare.transform_string(
        mail("""
        {Mutare.SwooshTest.Mailer.deliver(email), Mutare.SwooshTest.Mailer.deliver!(email)}
        """),
        mutators: [{Deliver, mailer: Mailer}]
      )

    variants = result.mutants |> Enum.flat_map(& &1.variant) |> Enum.sort()
    assert variants == ["deliver", "deliver!"]

    for site <- result.mutants do
      assert site.note =~ "assert_email_sent"
    end
  end
end
