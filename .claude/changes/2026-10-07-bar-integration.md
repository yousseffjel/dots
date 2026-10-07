# bar-integration
Date: 2026-10-07
Files: 23 | Lines: +806/-46 (before this log)

Scope F slot 2 of 4 (`.claude/tasks/scope-f-desktop-integration.md`, on main):
survey items I2, I3, I4 and A2.

## What changed
- New sourced helper `suckless/dwmblocks/scripts/dwm-blockutil`, alongside
  `dwm-colors` and installed 644 like it (the Makefile line was edited):
  - `block_bin` looks on PATH first, then in `~/.config/dwm/bin`.
  - `block_term <tool> <cmd>` opens alacritty, or st, with class
    `dots-float-<tool>`, backgrounded with its output detached.
  - `block_osd` shows the `dwm-osd` pop-up.
- `suckless/dwm/config.def.h`: one `dots-float-` rule floats every terminal a
  block opens (rules match by strstr). It replaces slot 1's `dots-nmtui`.
- Clicks:
  - VOL left/scroll and MIC left: the `dwm-osd` pop-up, as the keys show.
  - GAMMA: scroll runs `dwm-brightness up/down` and shows the pop-up; left
    toggles `dwm-nightlight`, detached as a whole group so the block's
    stdout is not held.
  - CPU, MEM, TEMP: left-click opens htop. These blocks are polled, so they
    load the helper only for a click.
  - UPD: right-click runs `sudo dnf upgrade --refresh` in a terminal. It
    signals RTMIN+1 when dnf exits and holds the window until Enter. It is
    handled before the cache check, so it works while the block reads n/a.
  - NET: uses `block_term`, class `dots-float-nmtui`.
- **Bug fix, UPD:** the left-click list included dnf5's "Upgrades" header
  line. The count and the list now come from one filter.
- Test hooks: `DOTS_PROC_ROOT` for cpu/mem (precedent: `DOTS_HWMON_ROOT`).
- Tests:
  - New `tests/blocks-{audio,system,info}.sh` + `tests/lib/blocks.sh`
    (sealed PATH, `env -i`, dwm-* fakes in `~/.config/dwm/bin` the way
    dwmblocks finds them).
  - `tests/dwm-net.sh`: new class.
  - `tests/lib/dwm-runtime-floating.sh`: a rule ending in `-` is tested
    with a class that only starts with it.
- `KEYBINDINGS.md` § Status bar: the clicks column and a paragraph on the
  floating terminals and the pop-up.

## Why
The scope F survey found the bar and the keys behaving differently. The
volume keys show a pop-up but bar scrolls did not; four blocks took no clicks;
the updates block could list updates but not apply them. Ten of the twelve
block scripts had no test (A2). The user picked all four items on 2026-10-07.

## Assumptions
- Type B: one shared helper rather than a third copy of dwm-net's
  terminal-pick loop. Stated in `/plan`.
- Type B: one `dots-float-` prefix rule rather than a rule per pop-up, so a
  new pop-up needs no dwm rebuild. Stated in `/plan`; the coupling to
  `block_term` is tested.
- Type B: htop on CPU/MEM/TEMP, GAMMA left = night light, and UPD right =
  upgrade come from the survey's proposals. The user approved the plan
  without changing them.
- Type C: a missing dwm-blockutil costs a block its clicks, never its output.
  Round-1 review caught GAMMA breaking this; fixed and tested.

## Test coverage
- `tests/run-tests.sh`: 46/46 OK (43 + three new), 0 skipped.
- Fakes copy real output, captured 2026-10-07:
  - pamixer and `df -P -h /` from the dev host;
  - bluetoothctl from bluez on the dev host;
  - `dnf check-update` from dnf5 on the Fedora 44 VM (exit 100, an
    `Upgrades` header, 37 lines).
- The right-click upgrade command is run for real against fake sudo/pkill:
  order `sudo dnf upgrade --refresh` then `pkill -RTMIN+1 dwmblocks`.
- Mutations on tree copies: 16/16 caught. B13, renaming the rule prefix, is
  caught only by the new block_term-vs-rules[] coupling check.
- Not run: the blocks under dash, which is CI's `/bin/sh`. Absent on the dev
  host; a static scan of the touched scripts found no bashisms. CI is the
  first dash run.
- Reviewer: WARN (GAMMA's render depended on the helper), fixed, then READY.
  The reviewer's run had unstaged the index; contents were unchanged and
  re-staged.

## Follow-ups
- Slot 4 (VM), after merge + push: `git pull && scripts/install-suckless.sh`
  (dwm needs `rm -f suckless/dwm/config.h` first for the new rule) and a
  re-login. Then check:
  - each click, with the pop-up showing;
  - htop and the upgrade terminal float;
  - the sudo prompt works inside the terminal.
- Watch the first CI `tests` run: it executes the blocks under dash.
- Next: slot 3, `session-integration` (F3, I1, I5).
