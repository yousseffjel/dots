# wallpaper-collection
Date: 2026-10-13
Files: 17 | Lines: +569/-19

## What changed
- **New `scripts/install-restore-wallpapers.sh`** (sourced by the restore stage,
  before `restore_theme`): shallow-clones `DOTS_WALLPAPER_REPO` (default
  `https://github.com/yousseffjel/wallpaper.git`; empty = skip) into
  `<xdg pictures>/wallpapers/dots`. Writes one `WALLPAPERS <url> <dir>
  <top-most dir created|->` row. A re-run (so `dots update`) `pull --ff-only`s
  a clone it owns; a directory already at the path is left alone and never
  recorded. A failed clone/pull is a yellow line, never an abort. Defines
  `wallpaper_collection_dir`, also used by `wallpaper.sh`.
- **New `scripts/uninstall-wallpapers.sh`** (`uninstall_wallpapers`, before the
  package step): removes the clone only while git proves it unchanged — same
  `origin`, `status --porcelain` empty (untracked counts), `@{u}..HEAD` empty —
  then prunes the parent dirs the clone created. Otherwise keeps it and says why.
- **`scripts/theme/wallpaper.sh`**: `--initial` (random from the collection
  only; quiet exit 0 without one) and `--login-random on|off|status` (flag file
  `~/.config/dots/random-wallpaper`; `on` prints the three `.xinitrc` lines when
  the user's file does not read the flag yet).
- **`.xinitrc` template** (`install-session.sh`): the cached-theme branch runs
  `timeout 120 dots wallpaper --random` when the flag exists, falling back to
  `~/.fehbg`; the first-login branch runs `dots wallpaper --initial` after
  `dots theme dark`.
- **`install-restore-theme.sh`**: the initial apply runs `--initial` only when
  this run made the clone (`WALLPAPERS_CLONED`).
- **`scripts/theme/colorgen.sh`**: the working copy is shrunk to ≤1920x1080
  (`-resize '1920x1080>'`) before `-kmeans`.
- Tests: new `tests/wallpaper-collection.sh` (22 checks); `xinitrc-theme.sh`
  +2 cases and 2 updated expectations; `install-uninstall-symmetry.sh` now
  requires WALLPAPERS rows; `tests/lib/install-symmetry.sh` gained a local bare
  fixture passed as `DOTS_WALLPAPER_REPO`, and its fake `git` lets clones from
  `$TMP` through to real git.
- Docs: THEMING.md ("The wallpaper collection", "A random wallpaper at every
  login"), UNINSTALL.md (step 5c + kept list), themes/dark/wallpapers/README.md,
  CHANGELOG [Unreleased] (two Added entries), CLAUDE.md project map.

## Why
User request: "add them to the project" — the wallpaper repo cleaned earlier
this session (202 → 189 images: 4 byte-identical duplicates, 2 recoloured
copies, 7 below 1920x1080 removed; 8 mislabelled WebP renamed; 2 GIFs to PNG
stills; every file renamed `<category>-<description>[-nord].<ext>`; pushed by
the user as `5da2d12`). The user chose (AskUserQuestion): the installer clones
it; it lands in `~/Pictures/wallpapers`; a random wallpaper on each install.
Then asked for an option to get a random wallpaper at every login.

Respects the logged decision that no image is committed to this repo
(themes/dark/wallpapers/README.md; MASTER_PLAN "a theme carries no
wallpapers/"): nothing enters dots. zinit/TPM are the precedent for an
install-time clone; rule 4's third-party concern does not apply — it is the
user's own repo, explicitly requested.

## Key Technical Decisions
- **`wallpapers/dots/`, not `wallpapers/` itself.** theme-apply.sh seeds
  `wallpapers/` with the generated gradient, so on every existing install
  (the VM included) that directory exists and "skip if it exists" would never
  clone. wallpaper.sh's `find -L` recurses, so the subdir is picked up.
- **The initial random pick is gated on a fresh clone.** `theme_initial_apply`
  runs on every restore with a `DISPLAY` — `dots update` from a session
  terminal included — and an update must not swap the wallpaper.
- **The existing-`.xinitrc` paste lines live in `wallpaper.sh`**, printed by
  `--login-random on`, not in `session_xinitrc_report`: install-session-report.sh
  is at 244/250 lines, and the hint matters only once the option is on (it is
  off by default, so an install-time report would be noise for everyone else).
  `tests/wallpaper-collection.sh` holds the hint, the template and THEMING.md
  to the same three lines.
- **Scope addition, user-approved:** colorgen.sh shrink-before-kmeans. Measured
  in a sandbox: 15360x8640 PNG 61.7 s → 3.7 s; 7680x4320 WebP 16.2 → 2.7 s;
  4717x2984 9.6 → 2.5 s (identical palette); 3840x2160 4.6 → 2.1 s. Primary
  colours moved by 1–7 points per channel. With login-random on, that was
  login time (the VM is slower than the dev host; the 120 s timeout could
  fire). Committed static palettes are files, unaffected.

## Assumptions Made
- **Type B — default off** for `--login-random`: the user asked for "an
  option"; the recommendation (off) was given and not answered. Status: OPEN.
- **Type B — `wallpapers/dots/` subdirectory** (above). Status: OPEN —
  disclosed before /code.
- **Correction recorded:** the AskUserQuestion option text said "~80 MB" for
  the clone; that was the size of the user's last push. Real: ~400 MB download,
  773 MB on disk (measured). Corrected to the user before /code; docs carry
  the measured figures.

## Test coverage
- `tests/run-tests.sh`: exit 0, 55/55 OK (was 54).
- `tests/lint.sh`: shellcheck, shfmt, markdownlint all pass (fixed: one SC2034,
  one SC2016, one MD010 hard tab).
- Mutations 10/10 caught, on copies of the tree (ownership check, dirty check,
  ahead check, origin check, parent prune, manifest row, pull, empty-repo
  skip, flag path, `--initial` in the template); 3 spot-checked to fail on the
  intended assertion.
- Real network: `restore_wallpapers` twice in a sandbox HOME against GitHub —
  189 files at `5da2d12`, 49 s, 773 MB, one row; second run "up to date".
- Audit: one fix — `wallpapers_prune_parents` with an empty or "-" stop
  (a damaged row) matched every absolute path; now a no-op, proved on a
  scratch tree.
- Reviewer: READY, first round; worktree verified untouched afterwards.
- **Not verified:** anything on the Fedora VM or real hardware; the
  `--login-random` path under a real X login.

## Follow-ups
- On the VM: `git pull` + `dots update` — this first update clones the
  collection and, with a DISPLAY, switches to a random wallpaper once. Then
  `dots wallpaper --login-random on`, paste the three printed lines into
  `~/.xinitrc`, log out and in twice, and confirm a different wallpaper each
  time and no long login stall.
- Observed, not changed: `theme_initial_apply` re-applies `themes/dark` on
  every restore run with a DISPLAY, so a `dots update` from a session terminal
  resets colours derived from a user-chosen wallpaper. Pre-existing; worth a
  queue entry.
- Optional: the wallpaper repo still carries a 15360x8640 PNG and a 33 MB PNG;
  scaling them to 4K would cut the download.
