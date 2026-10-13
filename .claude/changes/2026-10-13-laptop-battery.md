# laptop-battery
Date: 2026-10-13
Files: 14 | Lines: +480/-16

## What changed
- New `suckless/dwmblocks/scripts/dwm-battery`, a POSIX sh block. It reads
  system batteries only: type Battery, with a scope that is not Device. It
  uses summed energy (µWh), else summed charge (µAh), else the average of
  `capacity` when units are mixed. It shows `BAT NN%`, with `+` while
  charging, and prints NOTHING without a battery. While discharging, the
  label is STATUS_WARN at 15% and STATUS_URGENT at 5%, with one
  notify-send per threshold crossed (critical urgency at 5%, stack tag
  `battery`). The state lives in `$XDG_STATE_HOME/dots/battery-alert` and is
  re-armed by charging or by recovering above 15%. A left-click
  notification shows the state, percent and ETA from power_now or
  current_now. All numeric reads go through `num()`, so empty or junk
  values become 0.
- `suckless/dwmblocks/blocks.def.h`: a row with interval 60 and signal 13
  (the first free one), before the clock.
- New `tests/blocks-battery.sh`. `tests/lib/blocks.sh` gains
  `DOTS_POWER_SUPPLY_ROOT`, puts `rm` on the sealed PATH, and `block()` now
  tolerates a block exiting non-zero.
- Docs: KEYBINDINGS (13 blocks, BAT row), docs/HARDWARE.md (laptop list),
  CLAUDE.md (block count, scope-h progress), CHANGELOG.

## Why
scope-h slot 3 (`.claude/tasks/scope-h-laptop-support.md`): a laptop
needs to see its battery and be warned before it dies. A desktop's bar must
not change.

## Key Technical Decisions
- **No daemon.** The block's 60 s timer is the poll, as the scope file
  preferred. A daemon would need rule 6's three-place autostart change and
  a `dots_session_end` stop.
- An empty block on a desktop costs no space: dwmblocks.c only appends the
  delimiter after a block that printed text.
- Alerts escalate only (low, then critical, never low after critical) and
  re-arm on charge, so the 60 s re-runs never repeat one.
- dots does not suspend or hibernate at critical. That is logind's and the
  user's call, and is out of scope.

## Assumptions Made
- (B) Thresholds of 15% (low) and 5% (critical), and a 60 s interval. At
  5% a laptop drains about 1%/min, so one tick of delay is acceptable.
- (C) The sysfs attribute names follow the kernel's power_supply ABI. The
  fixtures copy it; no real battery has been read (VM only).

## Test coverage
- `tests/blocks-battery.sh`: desktop with a mouse battery and AC prints
  nothing; energy, charge (two batteries) and mixed units; charging wins;
  full; colours at 15% and 5%; low, then no repeat, then critical, then no
  low after critical, then charge re-arms, then a fresh low; junk or empty
  values still render; missing notify-send still renders; click ETA both
  ways.
- Mutations on a copy: 11 of 11 caught, each by an explicit FAIL line
  after the harness fix. Before that fix, a crashing block aborted the test
  silently.
- dwmblocks compiled from a scratch copy with a regenerated blocks.h. Full
  suite exit 0 (64 scripts). Lint passed. Reviewer READY.
- VM (f44, no power_supply entries): the real block printed 0 bytes,
  exited 0, and wrote no state file.

## Follow-ups
- scope-h slots 4 (touchpad) and 5 (tuned-ppd + switcher).
- Deviation: tests/lib/blocks.sh changed beyond the plan (`rm` sealed,
  `block()` `|| true`). The second change benefits every block test.
