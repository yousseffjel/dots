# brightness-follows-display
Date: 2026-10-21
Files: 13 | Lines: +460/-19 (incl. this log)

## What changed
- `config/dwm/bin/dwm-brightness`:
  - `level_file`/`store_level` record the level the gamma path sets, and
    the nightlight path too, in `$XDG_STATE_HOME/dots/brightness`. With no
    XDG_STATE_HOME and no HOME, nothing is recorded and nothing aborts.
  - New `sync` (`sync_level`) re-applies the recorded level through
    `apply`. It does nothing on a backlight, without a record, or with a
    corrupt one.
  - `outputs()` lists only connected outputs that have WxH+X+Y geometry.
    That fixes a second bug.
- New `config/autorandr/postswitch.d/20-dots-brightness` (sh). It runs
  `dwm-brightness sync` with `$XDG_CONFIG_HOME/dwm/bin` first on PATH, and
  exits 0 when dwm-brightness is missing.
- `config/dwm/bin/dwm-display` runs `dwm-brightness sync` after a
  successful preset, but never after a failed one.
- `scripts/install-restore-apps.sh` deploys `postswitch.d/*` by glob, so the
  hooks are no longer named one by one.
- Tests: `tests/brightness-follows-display.sh` and the sourced
  `tests/lib/brightness-follows-display-deploy.sh`, split at the 250-line cap.
- Docs: THEMING.md (the hooks), HARDWARE.md, KEYBINDINGS.md (`sync` from a
  shell), the CLAUDE.md project map, and a CHANGELOG [Unreleased] Fixed line.

## Why
The bug, found on the Void VM: when the level is set while a screen is off,
that screen comes back at full gamma beside a dimmed one. The repro, without
the nightlight daemon: Virtual-2 off, `set 50`, Virtual-2 on, and it reads
1.0. With the daemon running there is no bug: `gammastep -m randr` writes
every CRTC, including one whose screen is off, and its 60 s tick would
re-apply anyway. My first two VM repros ran with the daemon up and so did
not reproduce it.

The second bug turned up in the same repro: `set` printed "failed to set
Virtual-2" and exited 1 for as long as a connected screen was off. xrandr
refuses `--brightness` on an output with no CRTC. Such outputs are now
skipped, and `sync` gives them the level once they are on.

## Assumptions
- Type B: the level is a separate state file, not dwm-nightlight's
  `brightness` file. While the daemon runs both are written, so a later
  sync never restores an older level than the last ramp.
  Alternative considered: one shared file. It would change what the daemon
  reads at start, which is outside this scope.
- Type B: `sync_level` has no nightlight branch of its own. A mutant showed
  one would be equivalent, because `apply` already defers to
  `dwm-nightlight apply` while the daemon runs.

## Test coverage
- The new test fails 10 times against main's code and passes on the slot.
  The switched-off-screen case fails against the old `outputs()`.
- Mutants were run on a scratchpad copy. All are caught except the deploy
  `chmod`, which is redundant because `cp` keeps the mode. It is
  pre-existing and kept as explicit intent.
- `tests/lint.sh` passes. The suite run after the `outputs()` fix had
  one failure: `tests/dwm-nightlight.sh`'s fake prints
  `HDMI-1 connected 1920x1080+0+0` with nothing after the geometry, and the
  regex required a trailing space. Real xrandr always prints more, but the
  regex now also accepts end of line (`( |$)`). After that: 106 OK, rc 0.
- On the VM, the slot's `dwm-brightness` was copied to /tmp with
  XDG_STATE_HOME under /tmp, so the VM's real state was never touched, and
  run without dwm/bin on PATH. With Virtual-2 off, `set 50` returned rc=0
  and dimmed only Virtual-1. With Virtual-2 back on it read 1.0, and after
  `sync` 0.50. Restored to 1.0 on both screens, both monitors active.
- Not verified: the hook run by a real `autorandr --change` or a udev
  hotplug on the VM. Not installed there (no push). Also unverified: the
  monitor-capture pixel check, which is still blocked by slock (pid 5167).

## Reviewer
- Round 1: READY. Round 2, after the `outputs()` fix: WARN. The WARN says
  `current()` still accepts any connected output, while `outputs()` now
  needs geometry. That is left as is: on the VM a switched-off output
  printed no `Brightness:` line in `xrandr --verbose`, so `current()` cannot
  read one. The other half of the WARN is that dwm-brightness sits at 248
  of 250 lines, so the next change to it must split it first.

## Follow-ups
- After the user pushes: `dots update` on the VM, then run
  `autorandr --change` with a screen dimmed, and check the hook.
