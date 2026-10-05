# theme-roster-identity
Date: 2026-08-12
Files: 20 | Lines: +1047/-76

## What changed

- **Three new static themes** — `themes/{gruvbox,nord,tokyo-night}/`, taking the
  roster from one to four. Each `colors.dcol` is **generated** by this repo's own
  `scripts/theme/colorgen.sh` from a four-block seed image, never hand-written,
  and each header records the exact seed hex. All three carry 89 `dcol_*` keys
  whose names are identical to `themes/dark`, and all three were confirmed to
  **regenerate byte-identical** from the documented seed.
- **`theme.conf` stopped being decorative.** It was *printed* by
  `theme-apply.sh` and nothing more; the identity writers that render it into
  `settings.ini` + `xsettingsd.conf` were reachable only from the installer, and
  read a hardcoded `themes/dark/theme.conf`. Now `theme-apply.sh` sources those
  same writers and calls them on every static switch, before
  `apply-templates`/`reload` run so `reload.sh`'s existing `pkill -HUP xsettingsd`
  serves the new values.
- **`scripts/install-restore-theme-identity.sh`** — `THEME_CONF_REL` became a
  `${VAR:-themes/dark/theme.conf}` default, and a new `THEME_IDENTITY_CLOBBER`
  (default `0`) plus a `theme_identity_may_write` helper decide replacement.
  Three-way rule: absent -> write; ours per the manifest -> write only when
  clobbering; **present but not ours -> never write, in either mode**, with a
  yellow line saying the identity was not applied there. The helper extraction
  shrank both writers from 33 to 26 lines.
- **`tests/theme-identity.sh`** (suite 12 -> 13, free CI pickup via the glob).
- **Docs** — `docs/THEMING.md` (rewritten "Static themes" section incl. the
  seed-image recipe), `themes/CREDITS.md` (a per-theme table with upstream +
  licence), `CLAUDE.md`, `TESTING.md`, `themes/dark/theme.conf`, and
  `config/theme/templates/theme/README.md`.

## Why

`MASTER_PLAN.md` queue item "More than one theme under `themes/`", opened
2026-08-12 from a fresh HyDE diff. `dwm-theme` already opened a dmenu picker
over `theme-apply.sh --list` and that list had exactly one entry — a picker with
nothing to pick.

Identity wiring was chosen over colours-only because the alternative ships
theme.conf files that do nothing. It also fixed a latent bug nobody had hit:
before this, editing `themes/dark/theme.conf` and re-running `theme-apply.sh`
changed nothing at all.

## Assumptions

- **Type B — palettes generated from seed images, not transcribed from published
  hex.** `themes/dark`'s own header records generation as the reason it is
  guaranteed to carry every key a template can reference. Consequence: these are
  "flavoured by" their upstreams, not faithful ports — the same wording
  `CREDITS.md` already used for Catppuccin. Only the four `dcol_pry` values are
  upstream's; every ramp is this engine's dark curve.
- **Type B — identity applies via the installer's existing writers, not a new
  `.dcol` under `config/theme/templates/theme/`.** Nothing in it is
  palette-derived, so a template would re-render an identical file on every
  wallpaper change (the reasoning already recorded for `xsettingsd.conf`), and a
  template cannot ask the manifest whether a file is ours — which the no-clobber
  rule requires. That README recommended the template route and now records why
  it was rejected.
- **Type B — a switch replaces a file we wrote; an installer re-run does not.**
  Both refuse a file the manifest does not claim. Without the asymmetry a switch
  could never change identity at all.
- **Type C — no `wallpapers/` dirs for the new themes**, per
  `themes/dark/wallpapers/README.md`.

## Test coverage

`tests/theme-identity.sh` — proves the *selected* theme's identity is what
lands, that an installer re-run never clobbers, and that a hand-written
`settings.ini` survives a switch. **9 of 9 deliberate mutations fail the suite.**

Two things about that test are load-bearing:

1. **It adds a sandbox-only fixture theme.** The claim "the selected theme is
   used" cannot be proved against shipped data, because all four `theme.conf`
   files carry identical values (see Follow-ups). Without a theme whose values
   match nothing shipped, a regression that re-hardcoded `themes/dark` would
   stay green forever.
2. **It stubs `apply-templates.sh` and `reload.sh`.** The real ones fire
   post-commands that `pkill` dunst and dwmblocks system-wide, which env
   sandboxing does not prevent. The stubs record their arguments, so the switch
   is still proved to have reached the engine with the right palette.

Also: step 1 was proved by **byte diff** — `settings.ini` and `xsettingsd.conf`
render identically before/after the parameterization for `dark`.

Full suite via CI's own job bodies: 11 OK, 0 failed, plus
`tests/lint.sh --strict` clean. **`tests/build.sh` was not run** — it needs
`dnf` inside a Fedora container and this dev host is Arch; CI's `build-suckless`
job is the only place it executes. Nothing here touches `suckless/`.

Nothing was run against a live X session.

## Follow-ups

- **All four `theme.conf` files carry identical values** — `Adwaita-dark` +
  `Papirus-Dark` + `JetBrains Mono` — because the repo declares exactly one dark
  GTK theme (Adwaita-dark is a GTK3 built-in; `packages/extra.lst` adds no
  other). This was flagged as a risk at plan time and landed; no packages were
  added to manufacture variety. Genuinely distinct identities are a *packaging*
  decision — a themed GTK theme plus matching icon set — not a code one.
- `/test`'s discovery table matches nothing in this repo (no `config.yml`,
  `package.json`, `Makefile`, pytest config, `go.mod`, `Cargo.toml`), so it
  falls through to "no test suite" on every task despite 13 test scripts
  existing. Worth adding `.claude/config.yml` with `test_command`.
- Scope was widened once mid-task, with approval, to cover `TESTING.md` and
  `config/theme/templates/theme/README.md`; `## Forbidden` narrowed from
  `config/theme/templates/` to `config/theme/templates/always/`.

## Lessons

- **A test that supplies a default never tests it.** The first mutation run had
  one survivor: flipping `THEME_IDENTITY_CLOBBER`'s default `0 -> 1` left the
  suite green, because the test set both new globals explicitly while
  `install-restore-theme.sh` sets *neither* and relies entirely on the shipped
  defaults. Removing the test's own assignments killed that mutant and a second
  one (default theme flipped to nord) that had not been written yet.
- **The stale doc was the file I did not create.** The reviewer's one finding
  was `themes/dark/theme.conf`, still describing the old report-only behaviour
  while the three *new* theme.conf files described the new one correctly.
  Writing the siblings correctly is exactly what made the original look done.
