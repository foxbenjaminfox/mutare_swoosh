defmodule Mutare.Swoosh.ProviderOptionTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Swoosh.ProviderOption

  defp provider_diffs(source), do: diffs_for(source, [ProviderOption], :swoosh_provider_option)
  defp mutateds(source), do: provider_diffs(source) |> Enum.map(&elem(&1, 1))

  defp mail(body), do: "defmodule Mail do\n  def build, do: #{body}\nend\n"

  test "removes a direct put_provider_option call by collapsing to the email" do
    muts = mutateds(mail(~s'Swoosh.Email.put_provider_option(email, :template_id, "tpl-1")'))
    assert muts == ["email"]
  end

  test "removes a piped put_provider_option stage via identity" do
    source = """
    defmodule Mail do
      import Swoosh.Email

      def build do
        new()
        |> put_provider_option(:dynamic_template_data, %{name: "Alice"})
      end
    end
    """

    assert mutateds(source) == ["Elixir.Function.identity()"]
  end

  test "removes an aliased put_provider_option call" do
    source = """
    defmodule Mail do
      alias Swoosh.Email

      def build(email), do: Email.put_provider_option(email, :template_id, "tpl-1")
    end
    """

    assert mutateds(source) == ["email"]
  end

  test "does not match other modules or other arities" do
    assert mutateds(mail(~s'Other.put_provider_option(email, :template_id, "tpl-1")')) == []
    assert mutateds(mail(~s'Swoosh.Email.put_provider_option(email, :template_id)')) == []
  end

  test "declares the delete variant and tags produced mutants with it" do
    assert ProviderOption.variants() == ~w(delete)

    result =
      Mutare.transform_string(
        mail(~s'Swoosh.Email.put_provider_option(email, :template_id, "tpl-1")'),
        mutators: [ProviderOption]
      )

    assert [site] = result.mutants
    assert site.variant == ["delete"]
    assert site.note =~ "no test asserts the provider option"
  end
end
