# manifest-has-path
Date: 2026-08-12
Files: 10 | Lines: +378/-72

## What changed

- **New shared primitive `manifest_has_path <TAG> <path>` in `scripts/global_fn.sh`**
  (7-line body, ~20 lines of rationale). Answers "did this installer create this
  file?" by reading field 3 of every row of one manifest category.
- **Three byte-identical read loops deleted and rewired onto it:**
  - `theme_is_ours` → `manifest_has_path THEME` (4 call sites in
    `install-restore-theme.sh`: `deploy_theme_file`, `theme_write_gtk_ini`,
    `theme_claim_fastfetch`, `theme_claim_gtk_css`)
  - `theme_backed_up` → `manifest_has_path THEMEBACKUP` (1 site,
    `theme_backup_preexisting`)
  - `app_is_ours` → `manifest_has_path APP` (1 site, `deploy_app_file` in
    `install-restore-apps.sh`)
- **`scripts/install-restore-theme.sh`: 248 → 223 lines.** It was 2 lines from the
  250-line cap and could not accept another edit.
- **`scripts/install-restore-apps.sh`: 170 → 156.** `scripts/global_fn.sh`: 120 → 148.
- **New `tests/manifest-has-path.sh`** (164 lines) — 11 assertions. Suite 9 → 10.
- **`CLAUDE.md`** — both enumerations of `tests/` updated for the 10th script.

## Why

The 2026-08-10 queue sweep closed the third and last known `pipefail`/SIGPIPE
site by converting `theme_is_ours` and `theme_backed_up` from
`manifest_rows … | cut -f3 | grep -qxF` into read loops; `app_is_ours` had
already been converted the same way. That fix was correct and left three
textually near-identical functions behind — recorded as an open follow-up
rather than closed in the same pass, because `global_fn.sh` is sourced by 12
scripts (including `uninstall.sh`, which *deletes files* based on manifest
rows) and the blast radius deserved its own slot.

The duplication was not merely untidy. The knowledge that makes the read loop
mandatory — that `grep -q` exits on first match, SIGPIPEs `cut`, and under
`pipefail` turns a successful lookup into exit 141 — was written out three
times in three different phrasings. Three copies of a subtle invariant is three
chances for one to be "simplified" back to the pipeline. It now exists once,
next to the function it governs, and a test fails if anyone reverts it.

This also closes queue item 1 without performing it: the 25 lines removed take
`install-restore-theme.sh` far enough below the cap that the split it was queued
for is no longer needed. MASTER_PLAN predicted exactly this subsumption.

## Assumptions

- **Type B — direct calls over thin wrappers.** `theme_is_ours(x)` could have
  been kept as a one-line wrapper around `manifest_has_path THEME "$x"`,
  preserving call sites and their self-documenting names. Chose direct calls at
  all six sites instead: it saves ~20 more lines in the file that was against
  the cap, and `manifest_has_path THEME "$dst"` names the manifest category at
  the call site, which the old name only implied. *If incorrect:* re-add two
  wrappers at the top of `install-restore-theme.sh` and one in
  `install-restore-apps.sh`; the call sites revert mechanically.
- **Type B — comment relocation, not deletion.** The THEME/THEMEBACKUP semantics
  (why two categories exist, why a pre-existing file is deliberately never
  recorded) is repo-specific and stayed in `install-restore-theme.sh` under a
  section banner; only the generic SIGPIPE rationale moved to `global_fn.sh`.
- **Type C — no arity guard on the new helper.** It reads `"$1"`/`"$2"` bare, so
  a one-argument call dies under `set -u`. This matches `manifest_set_meta` and
  `manifest_upsert_row`, which are equally unguarded, and a stale one-arg caller
  failing loudly is the desired outcome.

## Test coverage

Full suite via TESTING.md's documented runner (`for t in tests/*.sh; do bash "$t"; done`)
— **10/10, exit 0**, including `build.sh` (compiled all five suckless programs)
and `lint.sh`. `tests/lint.sh --strict` — the spelling CI uses — was run
separately and also passed.

New `tests/manifest-has-path.sh` — sources the shipped function rather than
reimplementing it, so it cannot pass against a rotted `global_fn.sh`:
- hits on all three tags; a path containing a space; category scoping (a THEME
  row must not answer for APP); miss; prefix (`gtk.cs`) and superstring
  (`gtk.css.bak`) both reject; missing manifest is a clean miss, not an error.
- **The regression itself:** on a 200k-row manifest with the target in first
  position, the shipped shape found it **5/5** and the pipeline it replaced —
  reproduced verbatim in the test — found it **0/5**. Same numbers the
  2026-08-10 sweep measured. The test tolerates the race resolving the other way
  on a slower machine and prints a loud note rather than passing silently.

Beyond the suite:
- `uninstall.sh --dry-run --yes` in a sandbox with **all four** XDG variables
  set: read the correct THEME/APP rows, left both fixture files in place, and
  the real `~/.local/state/dots/manifest` was untouched (verified by mtime).
- `version.sh` in the same sandbox reported the sandbox manifest path.
- `set -e` behaviour of the `cmd && continue` shape empirically confirmed rather
  than reasoned about.
- dunst held PID 6788 across every run — no template post-command escaped its
  sandbox.

**Not tested:** nothing ran against a real `dnf`, a Fedora box, a live X session,
or GitHub Actions. This host is Arch.

## Follow-ups

- **Unblocked, next slot — `roster-gap-fill`.** The 27 lines of headroom now in
  `install-restore-theme.sh` exist so the xsettingsd template can claim its
  manifest path and create its parent directory (the "engine-owned target with
  no static base config" path documented in
  `config/theme/templates/always/README.md`). Roster locked with the user:
  xsettingsd, udiskie, autorandr, `dwm-colorpicker` + xdotool, `dwm-display`,
  gpick in `extra.lst`. Rejected: arandr, xdg-desktop-portal-gtk.
- **`ROADMAP.md` §3 lists `xcolor` as the color picker — it does not exist in
  Fedora.** Only `texlive-xcolor` (a LaTeX package) matches. Verified against
  packages.fedoraproject.org. §3's compositor row is also stale (says nothing
  autostarts picom; fixed 2026-08-08), and §9's priority list is entirely closed.
- **`.github/workflows/ci.yml` pins `fedora:41`, which is EOL.** Fedora's active
  branches are now 43, 44 and Rawhide. Discovered incidentally while verifying
  package availability. The container image will eventually stop resolving.
- **`@resurrect-dir` in `config/tmux/conf.d/30-plugins.conf` still ignores
  `$XDG_STATE_HOME`** — unchanged here, still queue item 3. Note the lesson from
  the last sweep: that queue entry describes a symptom, and the TPM one like it
  turned out to have four more hardcoded sites than the entry implied.
- **Scope note:** `CLAUDE.md` was added to the plan's `## Allowed` mid-task and
  recorded under `## Deviations` — it enumerates `tests/` by filename twice and a
  10th script made both stale. Announced, not silent.
- **DECISION REVERSAL — this log was renamed after it was written.** It was
  first committed as `2026-08-10-manifest-has-path.md`, because the date was
  taken from the previous log's filename instead of from `date -u`, which is
  what `/commit` step 2 actually prescribes. The real date is 2026-08-12
  (`date -u`, corroborated by file mtimes: the queue-sweep log is Aug 10 12:04,
  this one Aug 12 12:58). `session-protocol.md` calls any rename other than
  archiving forbidden, so the collision was put to the user rather than
  self-excepted; they chose the rename. Rationale: the immutability rule exists
  to prevent silent rewriting of history, and the invariant it ultimately
  serves — a filename prefix that sorts correctly for `session-init`'s
  5-most-recent window and the 14-day archival trigger — is the thing a
  two-day misdate breaks. Left uncorrected, this log shared a prefix with
  `2026-08-10-queue-sweep-1-5.md`.
  **Note the commits `a48de6b` / `59d54d5` are stamped 2026-08-10 17:40/17:42**,
  which matches neither `date` nor the file mtimes and is not explained by any
  `GIT_*_DATE` override (checked — none set). Unresolved environmental oddity,
  recorded here so a future reader does not trust those two timestamps.
- **Pre-existing, found by the post-merge check — `tests/build.sh` was failing
  on main.** `suckless/*/config.h` are gitignored build artifacts; slock's dated
  2026-08-05, before the xresources patch, so it lacked `ResourcePref` while
  `slock.c` references it. Not caused by this change (never tracked by git) and
  invisible to CI (fresh checkout regenerates from `config.def.h`) — which is
  why the slot worktree passed and main did not. All five were cleared; they
  regenerate on the next `make`. The dwm/st/dmenu ones were the more dangerous
  case: those would have compiled *green* against a pre-xresources config.
- **Skill/rule discrepancy, unresolved:** `/commit` step 9 says run the 14-day
  archival sweep in every mode; `session-protocol.md` says it runs on **main**
  post-merge, not from a slot, to avoid multi-slot conflicts. Followed the rule
  (skipped). Moot this run — no log predates 2026-07-27 — but the skill text
  should be reconciled with the rule.
