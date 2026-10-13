# laptop-power
Date: 2026-10-13
Files: 24 | Lines: +650/-15

## What changed
- `packages/laptop.lst` gains `tuned-ppd`. The `extra.lst` note on
  power-profiles-daemon no longer cites the reversed decision 9.
- `scripts/drivers-laptop.sh`: `drivers_power` enables `tuned.service` and
  `tuned-ppd.service` with `--now`, only when they are not already enabled.
  A SERVICE row is written only for a unit this run enabled. Dry run is
  honoured, and a failure goes to FAILED_EXTRA.
- New `config/dwm/bin/dwm-power`, with get, set, menu (default) and
  available. It uses `gdbus` against `org.freedesktop.UPower.PowerProfiles`
  at `/org/freedesktop/UPower/PowerProfiles`, Set with a GVariant string.
  The current profile is marked in dmenu. Without a service it gives an
  explanation (notification plus stderr) and opens no dmenu. A refused Set
  gives an error and a critical notification. The parsed profile must match
  `^[a-z-]+$`.
- `config/sxhkd/sxhkdrc`: Super+Shift+p runs `dwm-power`. `dwm-powermenu`
  gains a `profile` entry only when `dwm-power available`.
- `doctor-drivers.sh`: on a laptop, warns when `tuned.service` is not
  enabled.
- `scripts/uninstall_steps.sh`: `uninstall_services` skips a unit that no
  longer exists (`systemctl cat` fails) and reports it as gone with its
  package.
- Docs: KEYBINDINGS (### Power profile), HARDWARE.md, CLAUDE.md (dwm-power
  in the bin list; scope-h complete), CHANGELOG.

## Why
scope-h slot 5, the last one: power profiles on laptops, through Fedora's
default daemon.

## Key Technical Decisions
- **tuned-ppd**, per scope-h locked decision 2: Fedora's default since f41.
  It Conflicts with power-profiles-daemon (ppd-service).
- **gdbus, not powerprofilesctl:** f43 and f44 ship that command only inside
  power-profiles-daemon (mdapi: no standalone package), which conflicts.
  gdbus (glib2) is already a doctor dependency.
- **Enable tuned.** tuned-ppd is D-Bus-activated and pulls in tuned on
  demand, but without tuned enabled the chosen profile is not re-applied at
  boot.
- Polkit: tuned-ppd.policy is `allow_active yes` for switch-profile, so
  there is no password at the seat, and over ssh the switch is refused and
  reported.
- uninstall_services now tolerates units removed with their package. It
  runs after uninstall_packages, and tuned's own %preun already disables
  the unit.

## Assumptions Made
- (B) Super+Shift+p is free in both sxhkd and dwm. `tests/key-collisions.sh`
  passes.
- (C) gdbus prints a string property as `(<'value'>,)`. Captured from real
  gdbus on the dev host (hostname1 Chassis), and the ServiceUnknown error
  shape was confirmed on the VM.

## Test coverage
- New `tests/dwm-power.sh`: get, available, an unexpected shape, desktop (no
  service: explains, no dmenu), menu marking and Set GVariant, an unchanged
  choice, Escape, set validation, a refused Set, an unknown command.
- `tests/lib/drivers-cases-laptop.sh`: tuned and tuned-ppd enabled with rows
  on a laptop; a re-run is a no-op; an already-enabled unit gets no row; a
  failed enable gets no row; dry run; a desktop gets nothing.
- `tests/dwm-menus.sh`: the laptop power menu has a profile entry that
  routes to dwm-power, and the desktop menu is unchanged.
- `tests/doctor.sh`: power ok or warn on a laptop.
- New `tests/uninstall-services.sh` (the step had no test): units disabled,
  removed units reported as gone (not red), a real failure red, dry run.
- Mutations: 11 of 11 caught, plus the uninstall guard and the profile
  validation each caught. Full suite exit 0 (67 scripts). Lint passed.
  Reviewer READY.
- VM (desktop path, no tuned-ppd): real gdbus ServiceUnknown matches the
  fake; available and get give rc 1; the menu notifies and opens no dmenu.
- Not verified: a real laptop with tuned-ppd (VM only).

## Follow-ups
- scope-h is complete: all 5 slots. On main, the Active entry in
  MASTER_PLAN should move to Recently Closed.
- Deviations: scripts/uninstall_steps.sh and tests/uninstall-services.sh
  were outside the plan's Scope.
