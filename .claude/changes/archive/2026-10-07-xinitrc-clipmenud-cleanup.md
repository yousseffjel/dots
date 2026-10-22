# xinitrc-clipmenud-cleanup
Date: 2026-10-07
Files: 8 | Lines: +136/-64 (plus this log and the task folder)

## What changed
- `scripts/install-session.sh` — `session_xinitrc_template`: one
  `dots_session_end` EXIT trap for every path. It `pkill -u "$(id -u)"`s
  `clipmenud` and `clipnotify`, then stops `dots-session.target` only if this
  script started it (`dots_session_target` flag). `trap 'exit 0' HUP INT TERM`
  now applies on the no-systemd path too, and `exec dwm` became a plain `dwm`
  so the trap can run at all. Installer messages no longer say "exec dwm".
- `scripts/install-session-report.sh` — third marker, `dots_session_end`.
  `session_xinitrc_report_session` takes the reason as arguments and prints
  one block that covers both a missing session target and a missing session end.
- `docs/THEMING.md` § Desktop portal — the same paste block, plus why
  clipmenud needs it; "before `exec dwm`" → "before dwm starts".
- `tests/xinitrc-theme.sh` — fake `pkill` + `id`; every case now expects the
  session-end lines; new no-systemd HUP case; new 2026-10-06-style fixture
  (target, no end) must get only the session-end report.
- `TESTING.md`, `CLAUDE.md` rule 6, `CHANGELOG.md` (Unreleased → Fixed).

## Why
User screenshot after logging out of dwm on the Fedora VM: ly's TTY flooded
with `Can't open X display` / `xsel: Can't open display: (null) : Connection
refused`. The pattern (one clipnotify failure, then xsel per selection, no
delay) is clipmenud's main loop. clipmenud is a shell script that holds no X
connection, so unlike every other autostart daemon it does not die with the
server; once orphaned, `clipnotify` and `xsel` fail instantly forever and its
stderr is ly's TTY. Nothing in `.xinitrc` cleaned up: the systemd path only
stopped the target, and the fallback path `exec`ed dwm.

Option chosen by the user (A of three): explicit pkill in `.xinitrc`.
Rejected: B, kill the session's process group (depends on unverified ly/xinit
pgrp behaviour, may kill user-started processes); C, clipmenud as a systemd
user unit (does nothing on the no-systemd path; unit availability in the
COPR package unverified).

## Assumptions
- Type B: `pkill -x clipmenud` matches the daemon — the autostart guard
  already relies on `pgrep -x clipmenud` naming it the same way.
- Type B: `pkill -u <uid>` also stops a clipmenud belonging to a second,
  concurrent X session of the same user. Accepted for a single-seat desktop.
- Type C: every other autostart daemon is an X client and exits with X.
  Inferred from what each program is, NOT observed on the VM.
- Diagnosis is from the screenshot + code only: ssh to the VM was refused
  (no key on this host), so the leftover process was never seen directly.

## Test coverage
- `tests/run-tests.sh` — full suite green (build.sh / lint.sh run in their
  own CI jobs; `tests/lint.sh` run separately, green).
- Mutation run on scratch copies (never the worktree): `exec dwm` restored,
  clipnotify pkill dropped, target flag never set, EXIT trap dropped — all
  caught. Dropping `trap 'exit 0' HUP INT TERM` survives on bash, the
  blind spot the test already documents (bash runs EXIT on a fatal HUP).
- The documented paste block was extracted from THEMING.md and run under
  `/bin/sh` with fakes: start ok → pkills then stop; start fails → pkills only.
- Reviewer: WARN — a header comment in the test spliced mid-sentence; fixed.

## Follow-ups
- Verify on the VM: replace its `~/.xinitrc` tail with the paste block (that
  file predates this change and is user-owned), log out, confirm a clean TTY
  and `pgrep -x clipmenud` empty. Needs ssh access (`ssh-copy-id`).
