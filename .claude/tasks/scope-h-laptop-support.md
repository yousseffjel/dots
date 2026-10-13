# Scope H — laptop support (desktop + laptop targets)

Opened 2026-10-13. The user asked for a PC/laptop checker and for the project
to work on both desktops and laptops, right after `dots drivers` landed.

## DECISION REVERSAL

Scope B's **locked decision 9** ("Target is a desktop PC, not a laptop … no
battery block, no power-profiles-daemon, no lid-close handling, no laptop-only
power daemons") and **locked decision 12** (brightness is xrandr gamma only,
because a desktop has no `/sys/class/backlight`) are **reversed** by the user
(2026-10-13, option B of the CONFLICT block):
dots targets desktops AND laptops. **A desktop keeps exactly today's
behaviour** (xrandr gamma, no battery block, no power daemon). Laptop
behaviour is added on top and activates only on a machine the checker calls a
laptop. Scope B's file is not edited; this file is the record of the reversal.

## Locked decisions (user, 2026-10-13)

1. **Override, not merge:** laptops get real features, not just a report.
2. **Features:** real backlight brightness, a battery block with a
   low-battery alert, touchpad (tap-to-click, natural scrolling,
   disable-while-typing), and power profiles via `tuned-ppd`.
3. **Laptop-only packages are installed only on laptops.** They're gated on
   the checker, like `dots drivers`, with manifest rows so uninstall reverts
   them. Desktops stay lean. Rejected: installing everywhere and letting the
   features disable themselves.
4. **The checker lives in `dots drivers` and `dots doctor`**
   (`drivers-detect.sh`). No new subcommand. Rejected: a `dots hardware`
   command.

## Slots (in order — 1 is the foundation every other slot reads)

1. `laptop-detect` — `drivers_chassis` in `drivers-detect.sh`, returning
   `laptop` / `desktop` / `unknown`. It reads `/sys/class/dmi/id/chassis_type`
   (8,9,10,14,31,32 = portable/laptop/notebook/sub-notebook/convertible/
   detachable) **or** any `/sys/class/power_supply/*` with `type=Battery`
   and `scope` not `Device` (so a wireless mouse's battery does not count).
   It also adds a new `packages/laptop.lst`, read **only** by
   `drivers-lib.sh` and only on a laptop, the same arrangement as
   `build.lst` and install-suckless.sh. `dots drivers` installs it.
   `dots doctor` reports the chassis and must not warn about `laptop.lst`
   on a desktop: `check_packages` globs every list, so it needs a
   chassis-aware skip. `tests/pkglist.sh` keeps covering the list by glob.
2. `laptop-backlight` — `dwm-brightness` uses `brightnessctl` when a
   `/sys/class/backlight` device exists and keeps xrandr gamma otherwise.
   The block label says which one is active (decision 12's "the label must
   not imply hardware brightness" still holds for gamma). `brightnessctl`
   goes in `laptop.lst`. Check whether the logind/udev permissions for a
   non-root user work without extra rules on Fedora.
3. `laptop-battery` — a new dwmblocks battery block (capacity, charging
   state), empty on a desktop like DND, plus a dunst warning at a low
   threshold and a critical one. Rule-6 three-place change if a daemon is
   involved (prefer the block's own timer over a new daemon). It must sit
   in the `dots_session_end` stop list if it loops.
4. `laptop-touchpad` — tap-to-click, natural scrolling and
   disable-while-typing for touchpads only (never mice). Choose between an
   Xorg `40-libinput` snippet (system file, sudo, manifest-tracked) and
   `xinput` at session start (user-level, rule-6 autostart entry).
   **Decide in the slot**, and present it to the user.
5. `laptop-power` — `tuned-ppd` (Fedora's default since f41, which conflicts
   with `power-profiles-daemon`), plus a switcher: a dmenu menu and a key,
   with an optional block. Check what Fedora Server ships before swapping
   anything.

## Open questions

- Is there a real Fedora laptop to verify on? The VM can emulate neither a
  battery nor a backlight, so without one slots 2–5 are fixture-tested only.
- `CLAUDE.md` rule 10's tier table and the `extra.lst` "rejected" header
  notes for brightnessctl and power-profiles-daemon must be updated in slot 1
  and slot 5 respectively. They currently cite decisions 9 and 12.

## Explore notes (2026-10-13)

- Host (dev box): `chassis_type` 3 (desktop), no battery, no backlight.
- Already laptop-neutral: xss-lock locks on suspend, logind suspends on lid
  close by default, nm-applet, blueman.
- mdapi f43+f44 200: brightnessctl, tuned-ppd, tuned, power-profiles-daemon,
  tlp, upower, acpi, thermald, xinput, xorg-x11-drv-libinput.
- Status-bar blocks today (13): bluetooth, brightness, clock, cpu, disk, dnd,
  mem, mic, net, temp, updates, vol (+ colors/blockutil helpers).
