# dwm-bin-tests
Date: 2026-09-28
Files: 7 + task folder | Lines: ~+720/-3

## What changed
- Four new tests cover the seven untested `config/dwm/bin/` scripts, so all
  nine now have one:
  - `tests/dwm-brightness.sh`: connected-output selection past a
    disconnected output that carries its own `Brightness:` line; the step,
    and the clamp to 10..100; every connected output written and no
    disconnected one; a failed read (dead X, **or `--verbose`-only
    failure**) writes nothing; `set` validation.
  - `tests/dwm-lock.sh`: the screen locks before DPMS; no
    `--transfer-sleep-lock`; no second daemon; a missing xss-lock or slock
    fails loudly while a missing xset only warns; the logind route and the
    slock fallback, with loginctl never called while the daemon is down;
    extra arguments rejected.
  - `tests/dwm-screenshot.sh`: each mode reaches maim with the right
    selector plus `--hidecursor`; xrdb `#ff8000` becomes slop
    `1.000,0.502,0.000,1`; Escape at slop or either dmenu prompt exits 0; a
    mistyped mode **or destination** is rejected before capture; a missing
    xclip still saves the file; an empty capture and a missing maim fail.
  - `tests/dwm-menus.sh`: every powermenu action, confirm-before-reboot,
    and no dmenu colour flags (powermenu, clipmenu). dwm-theme and
    dwm-wallpaper are run through a deployed-style symlink from a sandbox
    copy whose `scripts/theme/*.sh` are fakes.
- New shared `tests/lib/sealed-path.sh` (`seal_path` links real tools by
  absolute path; `fake`).
- TESTING.md entry and a CHANGELOG line.

## Why
Queued 2026-08-12, with dwm-brightness named the highest value. The user
chose "all seven" today.

## Assumptions
- Type B: one file for the four thin front ends, and one each for the three
  with real logic, to stay under the 250-line cap without a test per wrapper.
- Type C: a sealed PATH throughout, per memory. A prepended PATH lets "not
  installed" fall through to real binaries.

## Test coverage
- 17/17 mutations on sandboxed copies are caught. **Two survived the first
  pass**, and each exposed a weak assertion:
  - The brightness dead-X fixture also emptied the output list, so an
    unguarded read had nothing to write. A `--verbose`-only failure fixture
    now catches it, via the exact failure the script's comment names: every
    screen clamped to 0.10.
  - The screenshot typo check proved "maim not called", which a bogus mode
    satisfies anyway. It now asserts that the next stage's error is absent,
    and a mistyped-destination case was added.
- Harness traps met on the way: a fake calling an unsealed `cat`; a
  `0,/pat/{n;s}` sed that mutated every matching line up to the pattern;
  and a `$` inside a grep pattern matching nothing. Each validation mutant
  was re-applied by exact line.
- The real `xrandr --verbose` format was checked read-only before writing
  the fake. The reviewer also cross-checked `xprop`.
- Reviewer: WARN (a dead temp-file clause, since the script's EXIT trap
  removes the temp on every path). Removed, the comment corrected, and the
  mutant re-verified.

## Follow-ups
- none
