# night-light
Date: 2026-10-05
Files: 11 | Lines: about +450/-30 (two new files)

## What changed
- `config/dwm/bin/dwm-nightlight` (new): `daemon | apply | toggle | status`.
  Every apply is `gammastep -m randr -P -O <temp> -b <b>:<b>`. The
  temperature comes from fixed times (6500 K from 07:00 to 19:00, 4000 K
  from 20:00 to 06:00, linear ramps between) or 6500 K when toggled off. The
  brightness is a stored percent (100 by default, clamped 10-100). The
  daemon applies every 60 s (`sleep & wait`, and kills its pending sleep on
  TERM). It exits at once if another daemon is running.
- `config/dwm/bin/dwm-brightness`: while `pgrep -f '/dwm-nightlight daemon$'`
  finds the daemon, `get` reads and `apply` writes the stored level
  (`$XDG_STATE_HOME/dots/nightlight/brightness`) and calls
  `dwm-nightlight apply` instead of `xrandr --brightness`. Otherwise
  unchanged.
- Autostart (rule 6): an `if command -v gammastep` block in
  `session_autostart_services`, the paired `session_report_daemon`, and
  `dwm-nightlight` in `DAEMONS`.
- `config/sxhkd/sxhkdrc`: `super + n` → `dwm-nightlight toggle`.
- `packages/desktop.lst`: `gammastep` with consequence text.
- `tests/dwm-nightlight.sh` (new); `KEYBINDINGS.md`, `CHANGELOG.md`,
  `CLAUDE.md`.

## Why
Item 4 of the post-VM follow-ups, blue-light filter row, ⭐ option chosen
by the user (gammastep on fixed times). I had warned that the filter and
`dwm-brightness` both write the X gamma ramps and would undo each other,
and that doing it properly meant routing the brightness keys through it.
This slot does that: one writer.

## Key Technical Decisions
- gammastep's own daemon is not used: it re-applies its ramp on its own
  schedule and offers no way to change brightness at runtime. One-shot `-O`
  with `-P` from our own loop keeps a single writer. `-P` is required:
  without it each one-shot multiplies onto the previous ramp.
- The daemon is found by command line (`pgrep -f`), because a
  `#!/usr/bin/env bash` script runs as a process named `bash`.
- Duplicate guard, three iterations:
  - (1) `pgrep | grep -qvx $$`. The reviewer (WARN) and I both found the
    race: the pipeline's forked side carries the daemon's command line.
  - (2) `$(pgrep … || true)`. A stronger fake pgrep then showed that a
    compound `$( )` keeps a forked subshell alive with that command line
    while pgrep scans, so every new daemon would have exited at once.
  - (3) Final: capture, then skip `$$` and pids no longer in `/proc`.
  Verified with the real pgrep: the first daemon applies; a second exits 0
  without applying.
- `dwm-brightness` resolves the state path lazily. A top-level `$HOME` read
  broke `tests/dwm-brightness.sh`, which runs it under `env -i`.

## Assumptions
- Type B: fixed times and temperatures as constants in the script, with no
  location lookup.
- Type B: a display hotplug gets the night ramp back within 60 s, not at
  once.
- Rule 8: `gammastep` 2.0.11 verified on mdapi for f43 and f44.

## Test coverage
- `tests/dwm-nightlight.sh` passes in about 1 s. It covers:
  - the schedule, including the boundaries;
  - `-P` and `-b`, with clamping;
  - toggle;
  - the dwm-brightness routing both ways;
  - the duplicate guard;
  - SIGTERM, including the sleeper's death (a fake `sleep` records its pid).
- Mutations caught 11/11, among them: no `-P`, no floor, no dusk ramp, off
  ignored, orphaned sleeper, the guard counting itself or dead pids, no
  guard, and dwm-brightness ignoring the daemon in `get` or `apply`.
- Xvfb with the real redshift (same flags): the first apply set gamma
  1.0:1.3:1.6 at brightness 0.70, as intended. Later readbacks showed
  0.0, but so did plain `xrandr --brightness` on the third set, so Xvfb's
  gamma readback is not trustworthy; repeated applies need a real X server.
- `tests/run-tests.sh`: 35/35. Lint passed. Reviewer: WARN (the race), fixed;
  re-review READY.

## Follow-ups
- VM: confirm `pgrep -af dwm-nightlight` shows one daemon after login and
  after a dwm restart, Super+n visibly warms and cools the screen, and the
  brightness keys move while it is on.
