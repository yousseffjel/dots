# picom-autostart
Date: 2026-08-08
Files: 6 | Lines: +226/-8

## What changed

- `scripts/install-session.sh` — picom is now launched from the `autostart.sh`
  template, first, before dwmblocks/clipmenud/sxhkd/dwm-lock:

  ```sh
  if command -v picom >/dev/null 2>&1 && ! pgrep -x picom >/dev/null 2>&1; then
  	picom &
  fi
  ```

  Backgrounded with `&` rather than picom's own `-b`, matching the three daemons
  already there and keeping picom a child of the script dwm itself backgrounds.

- `scripts/install-session.sh` — matching branch in `session_autostart_report()`
  for users whose `autostart.sh` already exists (CLAUDE.md rule 6 makes that file
  theirs the moment it exists, so the installer prints the line rather than
  editing it), naming what breaks without it: no compositor, no vsync, and the
  tuned `~/.config/picom/picom.conf` read by nothing.

- `scripts/install-session.sh` — the heredoc was extracted into a new
  `session_autostart_template()`. `install_session_autostart()` was **already**
  65 lines against the 60-line cap before this task; the picom block took it to
  76. Now 23 + 56. The generated `autostart.sh` is byte-identical across the
  refactor (same sha256), so this is presentation only.

- `tests/autostart-daemons.sh` (new, 139 lines) — asserts the two daemon
  descriptions in `install-session.sh` stay in agreement.

- `KEYBINDINGS.md`, `docs/THEMING.md` — note the compositor requirement where a
  reader would hit the symptom (sxhkd section; a "compositor settings never
  apply" troubleshooting entry).

## Why

picom was packaged (`extra.lst`), configured (`config/picom/picom.conf`), themed
(`picom.dcol`, rewritten on every wallpaper change) and performance-tuned across
two sub-tasks of the roster Epic — and never launched by anything. `autostart.sh`
started dwmblocks, clipmenud, sxhkd and dwm-lock; picom was simply not in the
list. On a fresh install there was no compositor at all: no vsync, no fades, and
`picom.conf` was dead weight the theming engine kept dutifully regenerating.

The gap survived that long because `install-session.sh` describes the daemon set
**twice** and nothing checked the two copies against each other — the heredoc
that fresh machines get, and `session_autostart_report()` that existing installs
are told about. Adding a daemon to only one is silent in both directions: miss
the report and every existing install never runs it while the installer reports
nothing wrong; miss the heredoc and fresh installs get nagged about a line they
already have. Nothing else in `tests/` executes `install-session.sh` — it writes
to `$HOME` and is sourced, not run — so the drift had no other way of surfacing.
`tests/autostart-daemons.sh` closes that, in the same spirit as
`tests/picom-lockstep.sh` for `picom.conf` / `picom.dcol`.

## Assumptions

- **Type B — `&` over `picom -b`.** picom can daemonize itself; the three
  existing daemons are backgrounded by the script, and dwm already backgrounds
  `autostart.sh` as a whole. Chose consistency with the file over picom's own
  flag. Alternative considered: `picom -b`, which would detach picom from this
  script's process group. If wrong: swap the two lines in
  `session_autostart_template()`.

- **Type B — compositor first in the file.** Started before the other four so
  windows are composited from the moment they appear rather than popping in
  unredirected. Alternative considered: last, so a picom failure cannot delay the
  status bar. Rejected — each launch is backgrounded, so ordering costs nothing.

- **Type C — the report branch names consequences, the other daemons' do not
  uniformly.** Follows the `sxhkd` branch's precedent (which explains that every
  binding dies without it) rather than the terser `dwmblocks` one.

## Test coverage

- Full suite green in the slot worktree, 7/7: `autostart-daemons`, `build`,
  `fastfetch-template`, `lint`, `picom-lockstep`, `pkglist`, `starship-template`.
  `build.sh` compiled all five suckless programs against this branch's sources.
- Sandboxed `$HOME` runs (all four XDG vars overridden per the installer-sandbox
  rule): a fresh install writes `autostart.sh` mode 755, valid POSIX `sh`,
  shellcheck-clean; a re-run leaves an existing file byte-identical (rule 6); a
  pre-existing `autostart.sh` without picom is untouched and the missing line is
  printed.
- **5 mutants, all caught.** Two of them found bugs in my own test rather than in
  the code:
  - The first version of `autostart-daemons.sh` grepped the bare daemon name
    anywhere in each section. Both sections *discuss* their daemons in prose, so
    deleting `picom &` outright still matched my own explanatory comment and the
    test passed. Both sides now match on canonical markers — a backgrounded
    command in the heredoc, an `already starts X` line in the report.
  - My mutant runner piped the test's output through `sed`, making `$?` sed's
    status; every mutant reported NOT CAUGHT. Same family as the `pipefail`
    SIGPIPE trap already noted in this repo.
- The heredoc extraction was itself caught mid-task by the new test's
  "could not extract" guard, which fired on a stranded `chmod`/`green` tail left
  inside `session_autostart_template()`. That validated the guard as well as
  finding the bug.
- picom was **not** launched to verify visually — this dev host is Wayland, and
  starting it would composite over the live session.

## Follow-ups

- The installer has still never been run end-to-end on real Fedora hardware.
  This change does not alter that; `autostart.sh` is written correctly in a
  sandbox, unproven on a real X session.
- `picom` sits in best-effort `extra.lst`, so a failed install leaves the
  `command -v picom` guard falling through silently. That is the existing
  `core.lst` vs `extra.lst` review already queued in `MASTER_PLAN.md`.
- Existing installs (including the user's own) need the printed line pasted into
  `autostart.sh` by hand — rule 6 forbids the installer from doing it.
