defmodule Mutare.Swoosh do
  @moduledoc """
  Custom Mutare mutators for Swoosh email semantics.

  The families mutate the semantic fields that tests often forget to assert: recipient class,
  sender, body part, subject, attachments, custom headers, provider options — and delivery
  itself. Each email-field family also mutates matching Swoosh.Email.new/1 options, so both
  pipeline construction and compact new options are covered.

      [mutators: [:builtins] ++ Mutare.Swoosh.all()]

  `Mutare.Swoosh.Deliver` needs to know the application's mailer module; `all/1` configures it
  in place:

      [mutators: [:builtins] ++ Mutare.Swoosh.all(mailer: MyApp.Mailer)]

  Without the option the deliver family stays inert (see `Mutare.Swoosh.Deliver`). `mailer:`
  takes one module or a list; every listed mailer records under the one `:swoosh_deliver` name
  (list `Mutare.Swoosh.Deliver` twice with `as:` to report them separately).
  """

  @families [
    Mutare.Swoosh.Recipient,
    Mutare.Swoosh.Sender,
    Mutare.Swoosh.Body,
    Mutare.Swoosh.Subject,
    Mutare.Swoosh.Attachment,
    Mutare.Swoosh.Header,
    Mutare.Swoosh.ProviderOption,
    Mutare.Swoosh.Deliver
  ]

  @doc """
  This package's Swoosh mutator families, for splicing into :mutators.

  `Mutare.Swoosh.Deliver` is included unconfigured and produces no mutations until it is given a
  `mailer:` — use `all/1` (or list the `{Mutare.Swoosh.Deliver, mailer: ...}` tuple yourself) to
  activate it.
  """
  @spec all() :: [module()]
  def all, do: @families

  @doc """
  The same families with `Mutare.Swoosh.Deliver` configured:

      Mutare.Swoosh.all(mailer: MyApp.Mailer)
      Mutare.Swoosh.all(mailer: [MyApp.Mailer, MyApp.AdminMailer])
  """
  @spec all(keyword()) :: [module() | {module(), keyword()}]
  def all(opts) do
    opts = Keyword.validate!(opts, [:mailer])

    Enum.map(@families, fn
      Mutare.Swoosh.Deliver -> {Mutare.Swoosh.Deliver, mailer: opts[:mailer]}
      family -> family
    end)
  end
end
