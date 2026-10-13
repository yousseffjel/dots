# update-resilience
Date: 2026-10-13
Files: 13 | Lines: +343/-20

## What changed
- **Clone progress** (`scripts/install-restore-wallpapers.sh`): new
  `wallpapers_git_clone` — `git clone --depth=1 --progress … 2>/dev/tty` when
  `/dev/tty` is writable, `--quiet` otherwise. install-fedora.sh tees stdout and
  stderr into install.log, so git saw no terminal and printed nothing for the
  whole ~400 MB download.
- **`complete` stamp** (`scripts/install-fedora.sh`, `scripts/update.sh`):
  install-fedora.sh now sources global_fn.sh and, after a full run (no
  `--only-*`, no `--dry-run`) reaches its end, writes `META complete <commit>`
  (guarded: a failed write is a yellow warning). update.sh's
  `install_is_current` and `stale_reason` read `complete`, not `commit`; a
  missing stamp reads "no finished install recorded".
- **Active-theme re-apply** (new `scripts/install-restore-theme-active.sh`,
  `scripts/install-restore-theme.sh`): `theme_active` prints `--wallbash` when
  `wall.set` is newer than `theme.set` (or theme.set is absent) and its image
  still exists, else theme.set's theme when this checkout ships it, else
  `dark`. `theme_initial_apply` passes it to theme-apply.sh. Files are read
  with `cat || true`, so an unreadable one falls through instead of aborting.
- Tests: new `tests/install-complete-stamp.sh` (the real install-fedora.sh in a
  copied tree with stub stages: full / --skip-suckless stamp; --only-restore,
  --dry-run, a failing stage do not), new `tests/theme-active.sh` (8 cache
  states + theme_initial_apply against a fake DOTS_DIR), `tests/dots-update.sh`
  (stub writes both stamps; interrupted and lone-`--only` cases),
  `tests/wallpaper-collection.sh` (progress reaches a `script(1)` pty and not
  the logged streams; quiet with no terminal).
- Docs: README (`dots update` paragraph), THEMING.md (re-run theme, progress),
  CHANGELOG [Unreleased] Fixed x3, CLAUDE.md project map.

## Why
User, 2026-10-13, after the first VM run of wallpaper-collection: "it works,
add the download progress fix and the other fixes". On the VM the user had
pressed Ctrl-C twice during the package stage, after which `dots update` said
"already up to date"; and the earlier session noted that every restore re-run
with a DISPLAY reset colours to `dark`.

## Key Technical Decisions
- **DECISION REVERSAL** — update.sh's header said "Each install stage stamps
  that commit as it starts, so an install that failed partway still reads as
  current: re-run install-fedora.sh." Surfaced as CONFLICT DETECTED; the user
  chose option B (override with documentation). The per-stage `commit` stamp
  is unchanged (migrate/version still use it); `complete` is a second key.
- Progress to `/dev/tty`, not `--progress` into the tee: the log would fill
  with carriage-return progress lines. Trade-off: on the terminal path git's
  own error text reaches the terminal only; the yellow skip line is logged.
- `theme_active` tie (same mtime) counts as static.

## Assumptions Made
- **Type B — "the other fixes" = all three** (the two offered fixes plus the
  open dark-reset question). Stated to the user before planning. Status: OPEN.
- **Type B — every existing install re-runs the full installer once** on its
  next `dots update`, since none has a `complete` stamp yet. Intended; told to
  the user. Status: OPEN.

## Test coverage
- `tests/run-tests.sh`: exit 0, 57/57 OK (was 55).
- `tests/lint.sh`: passed (two SC2016 annotated for inner-bash bodies).
- Mutations 10/10 caught, each on its intended assertion (stamp always / on
  dry-run, update reading `commit`, theme_active always dark / no `-nt` / no
  image check, hard-coded `dark` in theme_initial_apply, progress to stderr /
  never / always).
- Audit: 2 fixes (set -e silent abort on `$(<file)`; unguarded final stamp),
  the first proved against a chmod-000 theme.set.
- Reviewer: READY, first round; worktree verified untouched.
- **Not verified:** on the VM. `/dev/tty` behaviour was exercised under
  `script(1)` and `setsid`, not under ly or a real login.

## Follow-ups
- On the VM after merge + push: `dots update` re-runs the full installer once
  (no `complete` stamp yet) — let it finish; confirm the clone/pull shows
  progress on a fresh clone elsewhere, and that the current wallpaper colours
  survive (`--wallbash` re-applied, not `dark`).
- Optional: downscale the 16K and 33 MB PNGs in the wallpaper repo.
