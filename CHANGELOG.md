# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-09-07

### Fixed

- **No compiler warning on Elixir 1.20.** The header family carried a
  catch-all clause its type inference proves unreachable, which 1.20 reports
  while compiling the dependency (and which failed the package's own
  warnings-as-errors CI). The clause is gone; behaviour is unchanged.

## [0.1.0] - 2026-09-07

Initial release.

### Added

- Eight mutator families over the Swoosh email surface, each reported under
  its own name and independently enable-able:
  - `Mutare.Swoosh.Recipient` (`:swoosh_recipient`) — swaps recipient classes
    (`to`/`cc`/`bcc`, and `put_to`/`put_cc`/`put_bcc` among themselves),
    deletes one recipient from literal recipient values, and weakens
    `put_* → ` plain (`append`) one-directionally — replace-semantics
    declared but untested (each such mutant carries an equivalence note:
    a kill may require pre-existing recipients).
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
  - `Mutare.Swoosh.Deliver` (`:swoosh_deliver`) — the marquee mutation:
    replaces `Mailer.deliver/1,2` with a non-delivering `{:ok, %{}}` (and
    `deliver!/1,2` with `%{}`), asking "does any test assert the email was
    actually **sent**?" Configurable with the application's mailer(s):
    `{Mutare.Swoosh.Deliver, mailer: MyApp.Mailer}`, or
    `Mutare.Swoosh.all(mailer: MyApp.Mailer)`; inert without it.
- Every email-field family mutates both the pipeline call and the matching
  `Swoosh.Email.new/1` option; calls match written qualified, aliased,
  imported, or piped.
- Ignore-variant labels throughout, so `# mutare:ignore[family:label]` can
  suppress one kind of mutant (e.g. `[swoosh_recipient:append]`,
  `[swoosh_deliver:deliver!]`).
- `Mutare.Swoosh.all/0` for splicing all families into a `:mutators` list;
  `Mutare.Swoosh.all/1` to configure the deliver family's `mailer:` in place.

[Unreleased]: https://github.com/foxbenjaminfox/mutare_swoosh/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/foxbenjaminfox/mutare_swoosh/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/foxbenjaminfox/mutare_swoosh/releases/tag/v0.1.0
