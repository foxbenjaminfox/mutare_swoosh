defmodule Mutare.Swoosh.SemanticsTest do
  # Selecting a mutant is VM-global (see Mutare.Test), so these live-mutant checks are not async.
  use ExUnit.Case, async: false

  import Mutare.Test

  alias Mutare.Swoosh.{Deliver, Header}
  alias Mutare.SwooshTest.Mailer

  test "an active deliver mutant returns {:ok, %{}} without delivering, direct and piped" do
    source = """
    defmodule Notifier do
      alias Mutare.SwooshTest.Mailer

      def direct(email), do: Mailer.deliver(email)
      def piped(email), do: email |> Mailer.deliver()
    end
    """

    {[mod], sites} = compile_metamutant(source, [{Deliver, mailer: Mailer}])

    assert {:ok, %{email: "mail"}} = mod.direct("mail")
    assert {:ok, %{email: "mail"}} = mod.piped("mail")

    direct_id = site_id(sites, {"Mailer.deliver(email)", "{:ok, %{}}"})
    piped_id = site_id(sites, {~r/deliver/, ~r/then/})

    assert with_active_mutant(direct_id, fn -> mod.direct("mail") end) == {:ok, %{}}
    assert with_active_mutant(piped_id, fn -> mod.piped("mail") end) == {:ok, %{}}
  end

  test "an active piped header-removal mutant passes the email through unchanged" do
    source = """
    defmodule Tagger do
      import Swoosh.Email

      def build do
        new()
        |> header("X-Tag", "welcome")
      end
    end
    """

    {[mod], sites} = compile_metamutant(source, [Header])
    id = site_id(sites, {~r/header/, "Elixir.Function.identity()"})

    assert mod.build().headers == %{"X-Tag" => "welcome"}
    assert with_active_mutant(id, fn -> mod.build() end).headers == %{}
  end
end
