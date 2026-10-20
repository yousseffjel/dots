# wallpaper-sh-posix-quoting
Date: 2026-10-05
Files: 4 | Lines: +104/-1 (3 modified + 1 new test; excludes state)

## What changed
- `scripts/theme/wallpaper.sh` writes `~/.fehbg` with POSIX single quotes
  (`'${TARGET//\'/\'\\\'\'}'`) instead of bash `printf %q`. This is the same
  form as `wallpaper-default.sh`, but without its
  `# dots: generated wallpaper` marker, because a picked wallpaper is the
  user's.
- New `tests/wallpaper-fehbg-quoting.sh` runs a sandbox copy of `scripts/`,
  with no-op fakes for colorgen/apply-templates/reload and a fake `feh`.
  The image path contains a space, `'`, `$` and a tab. It asserts that the
  file has no `$'...'`, runs under `/bin/sh`, passes the exact path to feh,
  and has no marker.
- TESTING.md entry; CHANGELOG.md Unreleased/Fixed.

## Why
For a control character, `%q` emits `$'...'`, which dash rejects. The
reviewer of `visual-defaults` flagged the bug in `wallpaper-default.sh`, where
it was fixed. `wallpaper.sh` had the same latent bug and was deferred as a
follow-up. Both `reload.sh` and the autorandr postswitch hook run this file.

## Assumptions
- The quoting expression is duplicated with `wallpaper-default.sh`, with a
  comment in each pointing at the other. A shared sourced file was judged
  not worth it for one line (rule 2's no-shared-file stance).

## Test coverage
- `tests/run-tests.sh`: 28/28 OK. `tests/lint.sh` clean.
- Mutations (scratch copy):
  - reverting to `%q`: caught by the tab;
  - adding the generated marker: caught.
- Reviewer gate: READY.

## Follow-ups
- none
