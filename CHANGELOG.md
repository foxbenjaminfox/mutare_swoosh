# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-26

### Changed

- **Breaking: Mutare 0.4.1 or newer is required** (`{:mutare, "~> 0.4.1"}`). Mutare
  now offers a pipe stage to a mutator as the call it is sugar for, so the families no
  longer carry pipe-specific replacements:
  - A removed piped stage reads as what was piped into it: `new() |> header("X-Tag", v)`
    → `new()` (was `header("X-Tag", v)` → `Elixir.Function.identity()`). The same holds
    for the `attachment/2`, `reply_to/2` and `put_provider_option/3` removals.
  - A piped `Mailer.deliver()` / `deliver!()` stage is replaced over the whole pipe:
    `email |> Mailer.deliver()` → `{:ok, %{}}` (was
    `Elixir.Kernel.then(fn _ -> {:ok, %{}} end)`). The email is still built.
  - `# mutare:ignore` directives and `--line` selections on a stage keep working as before.

## [0.1.1] - 2026-09-07

### Fixed

- **No compiler warning on Elixir 1.20.** The header family contained a
  catch-all clause that Elixir's type inference proves unreachable. Elixir 1.20
  reports this while compiling the dependency (which failed the package's own
  warnings-as-errors CI). The clause is gone; behaviour is unchanged.

## [0.1.0] - 2026-09-07

Initial release.

### Added

- Eight mutator families over the Swoosh email surface, each reported under
  its own name and independently enable-able:
  - `Mutare.Swoosh.Recipient` (`:swoosh_recipient`) — swaps recipient classes
    (`to`/`cc`/`bcc`, and `put_to`/`put_cc`/`put_bcc` among themselves),
    deletes one recipient from literal recipient values, and weakens
    `put_*` → plain (`append`) one-directionally — checking whether tests
    detect a failure to replace recipients (each such mutant includes an
    equivalence note: a kill may require pre-existing recipients).
  - `Mutare.Swoosh.Sender` (`:swoosh_sender`) — swaps `from` ↔ `reply_to`
    and drops `reply_to` (`delete` — replies silently go to `from`).
  - `Mutare.Swoosh.Subject` (`:swoosh_subject`) — blanks the subject
    (`subject(email, v)` → `subject(email, "")`; the `subject:` option in
    `new/1` is dropped).
  - `Mutare.Swoosh.Body` (`:swoosh_body`) — swaps `html_body` ↔ `text_body`.
  - `Mutare.Swoosh.Header` (`:swoosh_header`) — removes `header/3` and drops
    entries from a `headers:` option in `new/1`.
  - `Mutare.Swoosh.Attachment` (`:swoosh_attachment`) — swaps attachment
    disposition (`type: :inline` ↔ `:attachment`) and removes the
    `attachment/2` call / `attachment:` option entirely (`delete`).
  - `Mutare.Swoosh.ProviderOption` (`:swoosh_provider_option`) — removes
    `put_provider_option/3` (provider template ids and dynamic template data
    are exactly the untested things).
  - `Mutare.Swoosh.Deliver` (`:swoosh_deliver`) — skips delivery:
    replaces `Mailer.deliver/1,2` with a non-delivering `{:ok, %{}}` (and
    `deliver!/1,2` with `%{}`), checking whether tests assert that the email
    was actually **sent**. Configurable with the application's mailer(s):
    `{Mutare.Swoosh.Deliver, mailer: MyApp.Mailer}`, or
    `Mutare.Swoosh.all(mailer: MyApp.Mailer)`; produces no mutations without it.
- Every email-field family mutates both the pipeline call and the matching
  `Swoosh.Email.new/1` option; calls match written qualified, aliased,
  imported, or piped.
- Ignore-variant labels throughout, so `# mutare:ignore[family:label]` can
  suppress one kind of mutant (e.g. `[swoosh_recipient:append]`,
  `[swoosh_deliver:deliver!]`).
- `Mutare.Swoosh.all/0` for splicing all families into a `:mutators` list;
  `Mutare.Swoosh.all/1` to configure the deliver family's `mailer:` in place.

[Unreleased]: https://github.com/foxbenjaminfox/mutare_swoosh/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/foxbenjaminfox/mutare_swoosh/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/foxbenjaminfox/mutare_swoosh/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/foxbenjaminfox/mutare_swoosh/releases/tag/v0.1.0
