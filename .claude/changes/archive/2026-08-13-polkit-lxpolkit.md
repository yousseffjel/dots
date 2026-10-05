# polkit-lxpolkit
Date: 2026-08-13
Files: 12 | Lines: +60/-51 in the seven shipped files, plus this log and the
task folder.

## What changed

`polkit-gnome` is retired. Replaced with **`lxpolkit`** across the four sites
CLAUDE.md rule 6 couples together, plus docs.

- **`packages/desktop.lst`** — entry swapped, consequence text kept (it is
  load-bearing; `load_consequences()` reads it back).
- **`scripts/install-session-template.sh`** — the two-branch absolute-path
  fallback is **deleted**, not re-pointed, and the block **moved** from
  `session_autostart_services()` to `session_autostart_daemons()`. It now uses
  the same `command -v lxpolkit && ! pgrep -x lxpolkit` guard as picom, sxhkd
  and udiskie. `_daemons` 41 → 54 lines, `_services` 39 → 19 (cap 60).
- **`scripts/install-session-report.sh`** — the paste-this block collapses to
  the one-line form the other daemons use, and additionally tells anyone whose
  `autostart.sh` still carries the old polkit-gnome block to delete it: that
  block's `[ -x ]` guards can no longer match, so it has been doing nothing.
- **`tests/autostart-daemons.sh`** — `DAEMONS` entry.
- **Docs** — ROADMAP §3 auth-agent row and §4.1 list; `HANDOFF.md`.

## Why

Filed 2026-08-13 by the `install-container` job on its first run: `dnf list
--available polkit-gnome` does not resolve, so `install-dry-run` goes red
independently. Because the package sits in `desktop.lst` the install does not
abort — it prints the red consequence line and carries on, which is the tier
working as designed. The effect is that **every fresh install since the
retirement has shipped with no PolicyKit agent**: any GUI action needing
privileges is denied with no password prompt and often no error at all.

**The queue entry was wrong in both directions, and reading the package
metadata is what showed it:**

1. It said "retired on Fedora 44". `polkit-gnome` is absent from **f43 as
   well** — the repo's pinned oldest-supported image — so *every* supported
   target was broken, not just the newest. Verified with a control: `git`,
   `bash`, `picom` and `lxpolkit` all resolve through the same mdapi endpoint
   on f43, so the negative is real rather than an endpoint artefact. Its
   `packages.fedoraproject.org` page still returns **HTTP 200** and looks alive
   while listing only **EPEL 9**.
2. It prescribed "the absolute libexec path in both files". `lxpolkit`'s binary
   is at **`/usr/bin/lxpolkit`** — on `PATH` — so the correct change was to
   delete the fallback and use the ordinary guard. That also forced the move
   between functions: `session_autostart_services()`'s own header defines its
   membership as "services NOT on PATH", so leaving the agent there would have
   made that header false.

## Assumptions

- **Type C — `lxpolkit`** chosen by the user 2026-08-13 from four candidates;
  `polkit-kde` was excluded by the GTK-only roster (scope-B locked decision 3).
- **Type B — `pgrep -x lxpolkit` replaces `pgrep -f
  polkit-gnome-authentication-agent`.** `-x` matches `comm`, which is truncated
  at 15 characters; the package ships a `/usr/lib/.build-id` entry, so the
  binary is a compiled ELF whose `comm` is the 8-character `lxpolkit` rather
  than an interpreter name. Reasoned from the package's own file list, **not
  observed running** — no Fedora box.
- **Type C — two stale enumerations deleted rather than corrected**: a
  hardcoded "the three daemons above" (would have become four) and ROADMAP's
  "six of them" (the real number was nine). ROADMAP now points at the `DAEMONS`
  array instead of restating the list.

## Test coverage

**`/test` was invoked but discovery found nothing, and the run was not
completed — this is NOT "no test suite".** Fourth occurrence: all seven of the
skill's discovery priorities miss this repo while 15 test scripts exist and CI
runs every one. The fix is a `.claude/config.yml`, filed as a follow-up.

What was actually run:

- **14/14 test scripts pass.** `build.sh` is the only one skipped — it needs
  the X11 toolchain and runs in CI's Fedora container.
- **3/3 mutations caught** on the coupling rule 6 exists to protect: template
  updated without the report, report updated without the template, and
  `DAEMONS` left naming the retired package. Each fails the build.
- The **generated** `autostart.sh` was produced from the shipped function and
  checked with `bash -n`; launch order is preserved (agent still before
  `dwm-lock`).
- `tests/lint.sh` passes. markdownlint is absent on this host, so its "ok" is a
  skip — CI's `--strict` is the gate on the two markdown files touched.

**Unproven and unchanged:** nothing has run on Fedora hardware. `lxpolkit` has
never been started; only its packaging has been inspected.

## Follow-ups

- `/test` still cannot discover this repo's suite (4th occurrence). Needs a
  `.claude/config.yml` with `test_command` — a micro task of its own.
- Every remaining `polkit-gnome` mention outside `.claude/` is deliberate prose
  recording the retirement, plus one user-facing message telling people to
  delete their dead block. No functional reference remains.

## Lessons

- **The reviewer BLOCKed on a doc claim this task introduced.** The
  "Superseded" note was spliced into the *middle* of an existing `HANDOFF.md`
  sentence, stranding its tail so the paragraph asserted the code still tries
  two libexec paths — immediately after that fallback was deleted. **Third
  consecutive task where this gate caught a claim/reality gap**, and the second
  where four audit sweeps read the diff and the prose separately and missed it.
  **When superseding a historical note, leave the original sentence whole and
  append a dated paragraph — never interleave.**
- **Leaving the index empty worked.** The tier was computed with `git diff
  --shortstat HEAD` and nothing staged, so the reviewer read the working tree —
  the direct fix for the previous task's stale-index BLOCK.
- **A function's header comment is a membership rule, not decoration.**
  `_services` says "NOT on PATH"; obeying that is what turned a find-and-replace
  into a move, and what kept the file honest.
