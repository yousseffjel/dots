# laptop-detect
Date: 2026-10-13
Files: 26 | Lines: +600/-54

## What changed
- `scripts/drivers-detect.sh`: `drivers_chassis` returns laptop, desktop or
  unknown. It is a laptop when the SMBIOS chassis type is 8, 9, 10, 14, 31 or
  32, OR when `/sys/class/power_supply` has a Battery whose `scope` is not
  `Device` (so a mouse or headset battery does not count). 3/4/5/6/7/13/15/
  16/17/23/24/35/36 mean desktop; anything else is unknown, which gets
  desktop behaviour. Also `drivers_chassis_type`, `drivers_system_battery`
  and `drivers_chassis_why`.
- New `packages/laptop.lst` (`brightnessctl`) with a load-bearing
  `# chassis: laptop` header. `pkg_list_chassis` (install-pkg-tiers.sh) reads
  that header, so `dots doctor`'s glob over every list skips it off-laptop
  without naming it (rule 10). `install-pkg.sh` does not read the list.
- `scripts/drivers-lib.sh`: `drivers_laptop` installs `laptop.lst` only on a
  laptop, through `drivers_pkg`, so each install gets a PACKAGE row and
  uninstall reverts it. It runs first in `drivers_install`, and errors out
  loudly if `read_pkg_list` is not loaded. `scripts/drivers.sh` sources
  install-pkg-tiers.sh for it; `drivers-lib.sh` deliberately does not.
- `dots doctor`: a `drivers chassis` row, and `check_packages` skips a list
  whose chassis does not match this machine.
- `config/dwm/bin/dwm-brightness`: when `brightnessctl --class=backlight -m
  info` answers, get, up, down and set use the backlight. Otherwise the old
  xrandr gamma and night-light path runs, unchanged. A refused backlight
  write is an error, never a silent fall back to gamma. New `mode`
  subcommand prints `backlight` or `gamma`.
- `dwm-brightness-block`: the label is `BL` for a backlight and `GAMMA`
  otherwise, including when `mode` gives no answer.
- Docs: `docs/HARDWARE.md` gains a "Laptop or desktop" section.
  KEYBINDINGS.md, CLAUDE.md (rule 10 row, project map, Roadmap status note),
  the `extra.lst` note about brightnessctl, and CHANGELOG were updated.

## Why
The user asked for a PC/laptop checker and for dots to work on desktops and
laptops alike (scope-h, `.claude/tasks/scope-h-laptop-support.md`). This is
the foundation slot plus the first laptop feature.

## Key Technical Decisions
- **DECISION REVERSAL** of scope-b locked decisions 9 (desktop-only) and 12
  (gamma-only brightness), by the user on 2026-10-13 (option B of the
  CONFLICT block). A desktop keeps its old behaviour on every path. The
  reversal is recorded in the scope-h file; scope-b is not edited.
- **Slots 1 and 2 merged:** `tests/pkglist.sh` fails an empty `.lst`, and
  brightnessctl, the first laptop package, is only meaningful together with
  the backlight path. RECLASSIFICATION was announced in chat.
- A list declares the chassis it applies to in its own header instead of a
  consumer naming it (rule 10's "never name the lists").
- Unknown chassis is treated as a desktop: nothing laptop-only is installed
  on a guess. QEMU reports 1, "Other".
- The backlight goes through Fedora's brightnessctl, which is built with
  `ENABLE_SYSTEMD=1` and no udev rules, so writes go through logind and need
  no group or rule. Over ssh they are refused, and that is reported.

## Assumptions Made
- (B) The desktop chassis type list follows SMBIOS 3.x (3 Desktop … 36
  Stick PC). Types not listed are "unknown", which behaves as a desktop.
- (B) A battery without a `scope` file is the system's own. Kernel
  peripheral batteries (hid, hidpp) set `scope=Device`.
- (C) The brightnessctl `-m` format is `id,class,raw,NN%,max`, taken from
  upstream `brightnessctl.c`'s printf, and the fake copies it. It has never
  been run against a real brightnessctl: the dev host is Arch with no
  backlight, and the VM has none.
- Package names (rule 8): brightnessctl returns mdapi 200 on f43 and f44.

## Test coverage
- `tests/drivers.sh`: new chassis cases. Type 10 is a laptop and installs
  laptop.lst with a PACKAGE row. Type 1 plus a battery is a laptop. A
  desktop with a mouse battery stays a desktop. QEMU's 1 with no battery is
  unknown and installs nothing, as does a machine with no dmi. A missing
  parser is reported.
- `tests/dwm-brightness.sh` (+ `tests/lib/dwm-brightness-backlight.sh`):
  every old gamma case now also runs with brightnessctl present but no
  backlight device. New cases: mode, backlight get/up/clamp, refused write,
  unparseable line.
- `tests/blocks-audio.sh`: `BL` label, plus a mode with no answer, which
  shows `GAMMA`.
- `tests/doctor.sh`: chassis row; laptop.lst skipped off-laptop, and
  checked with a warn on a laptop.
- Mutations on a scratch copy: 10 of 10 caught. After the split, a backlight
  mutation still fails 3 moved cases, so the moved code runs.
- Full suite exit 0 (63 scripts). Lint passed. Reviewer READY.
- VM (f44, QEMU), read-only from a temp copy: chassis type 1 gives unknown
  and no laptop packages, doctor skips laptop.lst, and dwm-brightness gives
  mode=gamma, get=100.
- Not verified: any real laptop. The user has only the VM.

## Follow-ups
- scope-h slots 3 (battery), 4 (touchpad) and 5 (power profiles) are next.
  Slot numbering in the scope file is unchanged.
- Plan deviations: `tests/blocks-audio.sh` and
  `tests/lib/dwm-brightness-backlight.sh` were outside the plan's Scope. The
  plan's "fall back to gamma" risk note was built as an explicit error
  instead.
