# Progress — theme-roster-identity

## Status
`complete` — 6/6 steps, audit ✅ READY, reviewer READY (round 2). Awaiting
`/test` + `/commit`.

## Steps
- [x] 1. Parameterize `THEME_CONF_REL` so both writers read a caller-chosen theme dir; prove the installer path byte-identical for `dark`.
- [x] 2. Wire `theme-apply.sh` static mode to render identity from the selected theme, then confirm `reload.sh` already covers the HUP.
- [x] 3. Generate `colors.dcol` for gruvbox / nord / tokyo-night via seed image + `colorgen.sh`.
- [x] 4. Write each `theme.conf`, using only GTK/icon themes that `packages/*.lst` actually declares.
- [x] 5. Add `tests/theme-identity.sh` (suite 12 -> 13) proving the *selected* theme's identity is what lands.
- [x] 6. Update `docs/THEMING.md`, `themes/CREDITS.md`, `CLAUDE.md`.

## Verification
- Step 1 proved by **byte diff**: `settings.ini` and `xsettingsd.conf` render
  identically before/after the parameterization for `dark`. Manifest differed
  only by sandbox path.
- Step 2 proved end-to-end by running the real `theme-apply.sh` inside a sandbox
  repo whose `apply-templates.sh`/`reload.sh` are stubs — the real ones `pkill`
  dunst and dwmblocks system-wide.
- Step 3: all three palettes carry **89 `dcol_*` keys with names identical to
  `dark`**, and the four `dcol_pry` values are the seed hex verbatim.
- Step 5: **9 of 9 deliberate mutations fail the suite.** The first pass had one
  survivor — see Deviations note on defaults below.
- Full suite green: 12 pass, `build.sh` skipped (needs the Fedora container).
  `tests/lint.sh` (shellcheck + shfmt + markdownlint) clean.

## Deviations
1. **The mutation survivor was a test-design fault, not a code fault.** Flipping
   `THEME_IDENTITY_CLOBBER`'s default 0 -> 1 left the suite green, because the
   test set both new globals explicitly while `install-restore-theme.sh` sets
   *neither* and relies entirely on the shipped defaults. Removed both
   assignments from the test and asserted the defaults instead; the mutation now
   dies, as does flipping the default theme to nord. Recorded here because the
   lesson generalises: a test that supplies a default never tests it.
2. **All four `theme.conf` files ended up with identical values.** The plan
   flagged this as a risk and it landed: the repo declares exactly one dark GTK
   theme (`Adwaita-dark`, a GTK3 built-in) and one dark icon set. No packages
   were added to manufacture variety. The mechanism is proven by a sandbox-only
   fixture theme in the test rather than by shipped data.

3. **Scope widened mid-task, with approval.** Two files were touched by this
   change's *meaning* but sat outside `## Allowed` — one of them explicitly in
   `## Forbidden`. Surfaced rather than edited silently; the user chose to widen
   scope and fix both. `plan.md`'s Allowed/Forbidden/Scope were updated to match
   before either edit landed:
   - `config/theme/templates/theme/README.md` told a future contributor to add a
     template for exactly what this task implemented *without* one. It now
     records why a `.dcol` was rejected for identity (nothing is palette-derived,
     and a template cannot ask the manifest whether a file is ours).
   - `TESTING.md` gained the per-test rationale entry every other test has.
   `## Forbidden` narrowed from `config/theme/templates/` to
   `config/theme/templates/always/`, which is the part that genuinely must not
   change here.

## Blockers
_(none)_

## Reviewer round 1 — one real finding
`themes/dark/theme.conf` still described the old report-only behaviour while the
three new theme.conf files described the new one. The audit's own doc sweep
missed it because the three files I *wrote* were all correct. Fixed before the
round-2 READY.
