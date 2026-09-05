# mutare_swoosh

Mutation-testing mutators for [Swoosh](https://hexdocs.pm/swoosh), built as a
plugin for [Mutare](https://hexdocs.pm/mutare).

Email code has a signature test gap: the suite asserts *an* email was sent,
and nothing more. The wrong recipient class (`cc` where `bcc` protects
privacy), a reply-to that quietly falls back to `from`, a dropped attachment,
a provider template id nobody checks — or a `deliver` that never happens — all
pass such a test. `mutare_swoosh` mints *well-formed-but-wrong* Swoosh
programs at exactly those spots, so a **surviving** mutant points at the
precise assertion your suite is missing.

## Install

Add it (and Mutare) as dev/test dependencies:

```elixir
def deps do
  [
    {:mutare, "~> 0.1", only: [:dev, :test], runtime: false},
    {:mutare_swoosh, "~> 0.1", only: [:dev, :test], runtime: false}
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
`:swoosh_deliver` family stays inert and everything else still runs. Every
listed mailer records under the one `swoosh_deliver` name — to report mailers
separately, list the family twice with `as:`
(`{Mutare.Swoosh.Deliver, mailer: MyApp.AdminMailer, as: :swoosh_deliver_admin}`).
Each family records under its own report name and can be enabled on its own:

```elixir
[mutators: [:builtins, Mutare.Swoosh.Recipient]]   # just the recipient mutations
```

Then run Mutare as usual:

```
mix mutare
```

## The families

| Family | Name | Mutation | The gap a survivor exposes |
| --- | --- | --- | --- |
| `Mutare.Swoosh.Deliver` | `:swoosh_deliver` | replaces `Mailer.deliver/1,2` with a non-delivering `{:ok, %{}}` (`deliver!/1,2` → `%{}`) on the configured mailer(s) | **no test asserts the email was actually sent** — `assert_email_sent` |
| `Mutare.Swoosh.Recipient` | `:swoosh_recipient` | swaps recipient classes (`to`/`cc`/`bcc`; `put_to`/`put_cc`/`put_bcc`), deletes one recipient from literal values, and weakens `put_*` → plain (replace became append) | no test pins who the email goes to — the `cc`↔`bcc` swap is the privacy question |
| `Mutare.Swoosh.Sender` | `:swoosh_sender` | swaps `from` ↔ `reply_to`; drops `reply_to` | replies silently go to `from`; no test asserts the reply-to address |
| `Mutare.Swoosh.Subject` | `:swoosh_subject` | blanks the subject to `""` | no test reads the subject |
| `Mutare.Swoosh.Body` | `:swoosh_body` | swaps `html_body` ↔ `text_body` | no test distinguishes which body part carries the content |
| `Mutare.Swoosh.Header` | `:swoosh_header` | removes `header/3`; drops entries from a `headers:` option | no test asserts the custom header |
| `Mutare.Swoosh.Attachment` | `:swoosh_attachment` | swaps disposition (`type: :inline` ↔ `:attachment`); removes the attachment entirely | no test asserts the attachment exists, or how it displays |
| `Mutare.Swoosh.ProviderOption` | `:swoosh_provider_option` | removes `put_provider_option/3` | no test asserts the provider option — template ids and dynamic template data live here |

Every email-field family mutates both the pipeline call
(`email |> subject("Welcome")`) and the matching `Swoosh.Email.new/1` option
(`Email.new(subject: "Welcome")`). Calls match written qualified, aliased,
imported, or as a pipe stage, and every replacement is itself a valid Swoosh
program — a survivor means a missing assertion, not a crash.

## Ignoring one kind of mutant

The families declare ignore-variant labels, so a
`# mutare:ignore[family:label]` directive can suppress one kind of mutant
without silencing the whole family:

```elixir
email |> bcc(auditors)              # mutare:ignore[swoosh_recipient:cc] audit copy may be visible
email |> put_to(recipients)         # mutare:ignore[swoosh_recipient:append]
Mailer.deliver!(email)              # mutare:ignore[swoosh_deliver:deliver!]
email |> attachment(invoice_pdf)    # mutare:ignore[swoosh_attachment:delete]
```

The `put_* → plain` weakening (`append`) is deliberately **one-directional**:
writing `put_to` declares you care about replacement semantics, so that intent
should be tested; writing plain `to` declares no such intent, so there is no
reverse mutant. It is also the one mutant that can be *legitimately
equivalent* — when no recipients were set yet, replace and append coincide —
so each carries a report note saying a kill may require pre-existing
recipients.

## What's deliberately out of scope

- **`from` removal** — Swoosh validates the sender at delivery, so the mutant
  would only crash: an uninformative kill, not a test-quality signal.
- **Template rendering** — `render_body/3` and friends belong to
  [phoenix_swoosh](https://hexdocs.pm/phoenix_swoosh), and are covered by the
  companion `mutare_phoenix_swoosh` package.

## Development

The plugin is developed against a sibling checkout of Mutare
(`{:mutare, path: "../mutare"}`). The test suite runs against stand-in
`Swoosh.Email`/`Swoosh.Attachment` modules (`test/support/swoosh_stubs.ex`)
that mirror the real API — kept faithful by hand, since a real `:swoosh` test
dep would collide with them.

```
mix deps.get
mix test          # unit diffs + live semantic checks that a mutant actually changes behaviour
mix check         # format + credo + dialyzer
```

## License

MIT — see [LICENSE](LICENSE).
