defmodule Mutare.Swoosh do
  @moduledoc """
  Custom Mutare mutators for Swoosh email semantics.

  The families mutate email fields often left untested: recipient class,
  sender, body part, subject, attachments, custom headers, provider options — and delivery
  itself. Each email-field family also mutates matching Swoosh.Email.new/1 options, so both
  pipeline construction and compact new options are covered.

      [mutators: [:builtins] ++ Mutare.Swoosh.all()]

  `Mutare.Swoosh.Deliver` requires the application's mailer module in its configuration;
  set it with `all/1`:

      [mutators: [:builtins] ++ Mutare.Swoosh.all(mailer: MyApp.Mailer)]

  Without the option the deliver family produces no mutations (see `Mutare.Swoosh.Deliver`).
  `mailer:` takes one module or a list; mutants for all listed mailers are reported under
  `:swoosh_deliver` (list `Mutare.Swoosh.Deliver` twice with `as:` to report them separately).
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

  `Mutare.Swoosh.Deliver` is included unconfigured and produces no mutations until its
  `mailer:` option is set — use `all/1` (or list the `{Mutare.Swoosh.Deliver, mailer: ...}`
  tuple yourself) to activate it.
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
