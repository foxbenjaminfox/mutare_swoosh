# mutare_swoosh

[![Hex.pm](https://img.shields.io/hexpm/v/mutare_swoosh.svg)](https://hex.pm/packages/mutare_swoosh)
[![Hexdocs](https://img.shields.io/badge/hexdocs-docs-blue.svg)](https://hexdocs.pm/mutare_swoosh)
[![CI](https://github.com/foxbenjaminfox/mutare_swoosh/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/foxbenjaminfox/mutare_swoosh/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/mutare_swoosh.svg)](https://github.com/foxbenjaminfox/mutare_swoosh/blob/master/LICENSE)

Mutation-testing mutators for [Swoosh](https://hexdocs.pm/swoosh), built as a
plugin for [Mutare](https://hexdocs.pm/mutare).

Email code has a signature test gap: the suite asserts *an* email was sent,
and nothing more. The wrong recipient class (`cc` where `bcc` protects
privacy), a reply-to that quietly falls back to `from`, a dropped attachment,
a provider template id nobody checks — or a `deliver` that never happens — all
pass such a test. `mutare_swoosh` generates *well-formed-but-wrong* Swoosh
programs at those points. A **surviving** mutant indicates a change that
your test assertions did not detect.

## Install

Add it (and Mutare) as dev/test dependencies:

```elixir
def deps do
  [
    {:mutare, "~> 0.5.0", only: [:dev, :test], runtime: false},
    {:mutare_swoosh, "~> 0.2", only: [:dev, :test], runtime: false}
  ]
end
```

(Swoosh itself is **not** a dependency of this plugin — the mutators match
calls purely syntactically. Your own project already supplies Swoosh.)

## Enable

List the families in `.mutare.exs`, alongside Mutare's built-ins — naming your
mailer activates the delivery family:

```elixir
# .mutare.exs
[mutators: [:builtins] ++ Mutare.Swoosh.all(mailer: MyApp.Mailer)]
```

`:builtins` keeps Mutare's default families and *adds* the Swoosh ones.
`mailer:` takes one module or a list; without it (`Mutare.Swoosh.all()`) the
`:swoosh_deliver` family produces no mutations and everything else still runs.
Mutants for all listed mailers are reported under `swoosh_deliver` — to report
mailers separately, list the family twice with `as:`
(`{Mutare.Swoosh.Deliver, mailer: MyApp.AdminMailer, as: :swoosh_deliver_admin}`).
Each family has its own report name and can be enabled on its own:

```elixir
[mutators: [:builtins, Mutare.Swoosh.Recipient]]   # just the recipient mutations
```

Then run Mutare as usual:

```
mix mutare
```

## The families

| Family | Name | Mutation | Test gap indicated by a survivor |
| --- | --- | --- | --- |
| `Mutare.Swoosh.Deliver` | `:swoosh_deliver` | evaluates the original arguments and skips the configured mailer call, returning `{:ok, %{}}` (`deliver/1,2`) or `%{}` (`deliver!/1,2`) | **no test asserts the email was actually sent** — `assert_email_sent` |
| `Mutare.Swoosh.Recipient` | `:swoosh_recipient` | swaps recipient classes (`to`/`cc`/`bcc`; `put_to`/`put_cc`/`put_bcc`), deletes one recipient from literal values, and weakens `put_*` → plain (replace became append) | no test checks the recipients or their class — the `cc`↔`bcc` swap affects recipient privacy |
| `Mutare.Swoosh.Sender` | `:swoosh_sender` | exchanges two distinct single mailboxes in `new/1` options, and drops `reply_to` calls or options | no test checks the sender and reply-to addresses |
| `Mutare.Swoosh.Subject` | `:swoosh_subject` | blanks the subject to `""` | no test reads the subject |
| `Mutare.Swoosh.Body` | `:swoosh_body` | swaps `html_body` ↔ `text_body` | no test distinguishes which body part carries the content |
| `Mutare.Swoosh.Header` | `:swoosh_header` | removes `header/3`; drops entries from a `headers:` option | no test asserts the custom header |
| `Mutare.Swoosh.Attachment` | `:swoosh_attachment` | swaps disposition (`type: :inline` ↔ `:attachment`); removes the attachment entirely | no test asserts the attachment exists, or how it displays |
| `Mutare.Swoosh.ProviderOption` | `:swoosh_provider_option` | removes `put_provider_option/3` calls and drops entries from literal `provider_options:` maps | no test asserts the provider option — such as template ids or dynamic template data |

Email-field families cover pipeline calls and matching literal `Swoosh.Email.new/1`
options. They also recognize qualified, aliased, and imported calls. A surviving
mutant means the test run passed with the reported change active.

## Ignoring one kind of mutant

The families declare ignore-variant labels, so a
`# mutare:ignore[family:label]` directive can suppress one kind of mutant
without disabling the whole family:

```elixir
email |> bcc(auditors)              # mutare:ignore[swoosh_recipient:cc] audit copy may be visible
email |> put_to(recipients)         # mutare:ignore[swoosh_recipient:append]
Mailer.deliver!(email)              # mutare:ignore[swoosh_deliver:deliver!]
email |> attachment(invoice_pdf)    # mutare:ignore[swoosh_attachment:delete]
```

The `put_* → plain` weakening (`append`) is deliberately **one-directional**:
using `put_to` explicitly replaces existing recipients, so tests should check
that replacement; plain `to` only appends recipients, so there is no reverse
mutant. The two operations are *equivalent* when no recipients were set yet,
so each such mutant includes a report note explaining that a kill may require
pre-existing recipients.

## What's deliberately out of scope

- **`from` removal** — Swoosh validates the sender at delivery, so the mutant
  would only crash: an uninformative kill, not a test-quality signal.
- **Template rendering** — `render_body/3` and related functions are defined in
  [phoenix_swoosh](https://hexdocs.pm/phoenix_swoosh), and are covered by the
  companion `mutare_phoenix_swoosh` package.

## Development

The unit suite uses stand-ins for `Swoosh.Email` and `Swoosh.Attachment`. The isolated
Mix project in `integration/` runs active mutants against real Swoosh and checks
delivery through `Swoosh.Adapters.Test`. CI runs both suites.

```
mix deps.get
mix test          # unit diffs + live semantic checks that a mutant actually changes behaviour
mix check         # format + credo + dialyzer

cd integration
MIX_ENV=test mix deps.get --check-locked
mix test          # real Swoosh integration suite
```

## License

MIT — see [LICENSE](LICENSE).
