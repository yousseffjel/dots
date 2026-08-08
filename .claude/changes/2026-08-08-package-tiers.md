# package-tiers
Date: 2026-08-08
Files: 16 (12 modified, 4 new) | Lines: +278/-187 tracked, plus 360 lines of new files

## What changed

**The package model went from two lists to four.** Each tier now states a
different failure mode, which is the thing the old split could not express:

| List | Consumer | On failure |
| ---- | -------- | ---------- |
| `core.lst` (2) | `install-pkg.sh` | aborts the run |
| `build.lst` (13, new) | `install-suckless.sh` **only** | aborts the build stage |
| `desktop.lst` (26, new) | `install-pkg.sh` | never aborts; repeated in a red closing summary with what it costs |
| `extra.lst` (61) | `install-pkg.sh` | never aborts; one yellow line in the summary |

- **`core.lst` shrank to `git` + `zsh`.** `gcc`/`make`/`patch`/
  `pkgconf-pkg-config` moved to `build.lst`; they were only ever there for the
  suckless build. Deliberately not grown — see Assumptions.

- **`packages/build.lst` replaces the inline dnf array at
  `install-suckless.sh:84`**, closing the CLAUDE.md rule 10 violation. Two new
  guards: a missing list and a list that parses to zero packages both abort
  with a distinct message rather than running `dnf install` with no arguments.

- **`packages/desktop.lst` carries its consequence text inline.** The trailing
  `#` comment on each line is what breaks without that package, and
  `load_consequences()` reads it back out to build the failure summary.
  `read_pkg_list()` already strips trailing comments, so the install path is
  untouched and the fact lives on one line instead of in two files.

- **`scripts/install-pkg.sh` is now tier-driven** — one `install_tier()` loop
  taking a mode (`hard`/`desktop`/`extra`) in place of two near-identical
  hardcoded loops — and prints a closing summary naming every failure. It also
  keeps dnf's stderr instead of discarding it: failures previously all reported
  `skipped (not found in enabled repos)` whether the cause was a rename, a
  network drop, a GPG error or a transaction conflict.

- **`scripts/install-pkg-tiers.sh` (new, 117 lines)** holds that machinery.
  Folding it into `install-pkg.sh` took the file to 279 lines, over the
  250-line cap; split along the pattern `install-restore.sh` already uses with
  `install-restore-theme.sh`. Result: 181 + 117.

- **`tests/pkglist.sh` globs `packages/*.lst`** instead of naming two files, and
  its overlap check became all-pairs. New: no list may parse to zero packages.

- **`tests/desktop-consequences.sh` (new, 121 lines)** fails the build if any
  `desktop.lst` entry lacks a consequence note, is a sub-20-character
  placeholder, or has a note with no matching package. It extracts the *shipped*
  `read_pkg_list()` and `load_consequences()` rather than reimplementing them.

- **`ci.yml`'s dry-run job globs the lists too** — 102 packages across four
  lists, up from 96 across two. `build.lst`'s names had never been validated by
  CI at all, since they lived in an inline array.

- **Six packages that were declared nowhere are now declared.** Four
  (`libXext-devel`, `libXrandr-devel`, `libxcrypt-devel`, `ncurses`) existed
  only in that inline array. `procps-ng` supplies `pgrep`/`pkill`/`pidof`,
  called **unguarded** by `config/sxhkd/sxhkdrc`, `dwm-powermenu`, `dwm-lock`
  and the `dunst.dcol`/`picom.dcol` post-commands. `desktop-file-utils` supplies
  `update-desktop-database` (both call sites are guarded, so lower priority).

- **`patch` was in `core.lst` but missing from `install_deps()`'s own dnf list**,
  so a standalone `install-suckless.sh` on a box without it failed at the first
  vendored `.diff`. `build.lst` carries it.

- Docs reconciled: `CLAUDE.md` (project map, rule 10 rewritten as the tier
  table, the "still pending" bullet naming this very review, the stale sxhkd
  claim, and a test roster that was still missing `autostart-daemons.sh` from
  the previous task), `TESTING.md`, `docs/THUNAR.md`, `ROADMAP.md` §5/§4.1, and
  the `install-fedora.sh:145` comment that admitted `libxcrypt`/`ncurses` were
  needed but undeclared.

## Why

Five roster sub-tasks in a row — alacritty (3), sxhkd (4), maim/slop/xprop (5),
procps-ng (6), picom (2026-08-08) — each ended by deferring "should this be in
`core.lst`?" into a change log the next sub-task never read. The queue item
asked for one pass over the whole roster instead of a sixth follow-up line.

The answer turned out not to be a promotion list. The real problem was that a
two-tier model has no way to say *this failing is serious but must not abort the
install*. Everything load-bearing had therefore been parked in best-effort
`extra.lst`, where a failure printed one yellow line among ~110 green ones and
scrolled away. That is precisely how picom ended up packaged, configured, themed
and performance-tuned while nothing launched it. `desktop.lst` plus the closing
summary is the fix; the tier split is what makes the summary possible.

## Assumptions

- **Type B — `core.lst` shrank rather than grew.** The obvious reading of the
  queue item was "promote the load-bearing packages to `core.lst`". Rejected:
  `core.lst` hard-fails, CLAUDE.md rule 8 means every name here is hand-checked
  against packages.fedoraproject.org and never against a live `dnf`, and the
  installer has never run on real hardware. Each promotion would convert "one
  feature is dead" into "you get no desktop at all". Promotions went to
  `desktop.lst`, which shouts without aborting. *If wrong:* move entries from
  `desktop.lst` to `core.lst`; nothing else changes.

- **Type B — `install-pkg.sh` does not read `build.lst`.** `install-fedora.sh`
  runs `install-suckless.sh` immediately after, deliberately without
  `--skip-deps`, so the build stage installs its own dependencies right before
  it needs them. The useful consequence is that `--skip-suckless` needs no
  special handling anywhere. *Alternative considered:* install build deps in the
  package stage, which would then need the `--skip-suckless` flag threaded into
  `install-pkg.sh`.

- **Type B — `thunar` and `firefox` stayed in `extra.lst`** even though both are
  keybound, so both leave a dead key. Line drawn at infrastructure vs
  application: `sxhkd` failing kills every keybind at once and announces
  nothing, whereas a missing firefox is one obvious key. Both are still named in
  the closing summary, just not flagged as a broken desktop. **Raised with the
  user and left unanswered at commit time** — see Follow-ups.

- **Type B — the consequence text is a trailing `#` comment**, not a `case` map
  in `install-pkg.sh`. One source of truth on the line the name is read from,
  versus two files that drift the way the daemon set did.

- **Type C — the pacman and apt branches of `install_deps()` keep inline
  arrays.** A `.lst` holds one distro's package names and those are different
  names for the same libraries; only the dnf branch reads `build.lst`. Recorded
  as an explicit exception in rule 10 rather than left as a silent hole.

## Test coverage

- Full suite green, 8/8: `autostart-daemons`, `build`, `desktop-consequences`,
  `fastfetch-template`, `lint`, `picom-lockstep`, `pkglist`,
  `starship-template`. dunst held PID 6329 throughout.
- **Tier logic driven end-to-end against a fake `dnf`**, five scenarios: clean
  run; two desktop failures (summary named both with their consequences); two
  extra failures; a `core.lst` failure (aborted, `rc=1`); and a `desktop.lst`
  entry with its note stripped (fell back to "consequence not recorded").
- **`install_deps()` driven against a fake `dnf`** — 13 packages in list order,
  comments stripped. Both new guards fire with distinct messages and `rc=1`.
- **CI's real step body extracted from the YAML and run locally**: 102 packages
  over 4 lists; planted bad names in `build.lst` and `desktop.lst` each produced
  the right `::error file=` annotation and `rc=1`.
- **Nine mutants, all caught, each confirmed applied before judging.** Five
  against `pkglist.sh` (cross-tier duplicate, invalid name, in-list duplicate, a
  whole tier commented out, and a *fifth* list added with a duplicate — the last
  proving the glob covers a future tier). Four against
  `desktop-consequences.sh`, including renaming `load_consequences()` and
  breaking its regex **inside the shipped file**, which proves the test
  exercises the real parser rather than a private copy.
- Verified no package was silently lost: 96 → 102 with an explicit diff, zero
  dropped, and the six additions all accounted for.
- **Nothing ran against a real `dnf`** — there is none on this Arch dev host.
  Package names are checked against packages.fedoraproject.org per rule 8, and
  all six new names were carried over from code that already named them or from
  verified usage sites, not invented.

## Follow-ups

- **`polkit-gnome` is packaged but nothing autostarts it** — the identical bug
  shape to picom, found while reconciling ROADMAP §5 and flagged in that table.
  Out of scope here (`install-session.sh` is not in this plan's `## Scope`).
- **Unanswered question at commit time:** whether keybound applications
  (`thunar`, `firefox`) belong in `desktop.lst` rather than `extra.lst`. Moving
  them is a one-line edit per package plus a consequence note.
- `read_pkg_list()` now has three copies plus an inline one in `ci.yml`. Kept
  per CLAUDE.md rule 2 (per-script helpers over a shared sourced file) and each
  copy points at the canonical one, but `global_fn.sh` — already sourced by both
  installers — is where it should go if it ever grows past one line.
- Build deps still get no manifest rows, so `uninstall.sh` will not remove them.
  Pre-existing: the inline array wrote none either. Not a regression, but now
  that they are declared in a `.lst` the asymmetry is more visible.
- Three tiers means `install-pkg.sh` prints ~100 green lines before the summary.
  If that stays noisy, consider printing only failures plus a per-tier count.
