# laptop-touchpad
Date: 2026-10-13
Files: 21 | Lines: +560/-40

## What changed
- New `config/xorg/40-dots-touchpad.conf`: an InputClass with
  `MatchIsTouchpad "on"` and `Driver "libinput"`, setting `Tapping` on,
  `NaturalScrolling` true, `DisableWhileTyping` true and `ClickMethod`
  clickfinger.
- New `scripts/drivers-laptop.sh`. `drivers_laptop` moved here from
  drivers-lib.sh, and the new `drivers_touchpad` (laptops only) copies the
  snippet with `sudo install -D -m 644` to `/etc/X11/xorg.conf.d`
  (`DOTS_XORG_CONF_DIR` overrides it for tests). It writes a **new manifest
  category**, `SYSFILE xorg <installed> <repo path>`. A re-run replaces a
  claimed copy only while `file_matches_history` proves it unedited. An
  edited or unclaimed file is kept and named. Dry run is honoured. A
  failed write goes to FAILED_EXTRA with no row.
- New `scripts/uninstall-sysfiles.sh`, wired into uninstall.sh before
  `uninstall_packages` (it needs git). It removes a SYSFILE path only while
  it is unedited; an edited one is kept and named.
- `doctor-drivers.sh`: on a laptop, a missing snippet warns, and dots' own
  copy and an edited copy are both ok, each reported as such.
- Docs: HARDWARE.md (touchpad bullet), UNINSTALL.md step 5e, CLAUDE.md
  (config/xorg, drivers-laptop.sh, SYSFILE, uninstall-sysfiles.sh,
  scope-h progress), CHANGELOG.

## Why
scope-h slot 4: tap-to-click and the other touchpad behaviours people expect
on a laptop. libinput defaults tapping to off.

## Key Technical Decisions
- **Xorg snippet, not xinput at session start** (user, 2026-10-13). It
  matches by libinput's own touchpad classification, handles hotplug, needs
  no rule-6 autostart change, and existing installs need nothing pasted.
  The cost is sudo and a re-login.
- **All four behaviours on** (user, 2026-10-13).
- `Driver` rather than the `MatchDriver` the user was shown: /etc conf.d is
  read before /usr/share, where Fedora's 40-libinput.conf assigns the
  driver. The user was told.
- SYSFILE extends the APP rows' contract (replace or remove only while
  unedited) to root-owned files. It is a new category rather than a reuse
  of REPO's `file` kind, which removes by "package not installed".

## Assumptions Made
- (B) Xorg reads /etc/X11/xorg.conf.d before /usr/share/X11/xorg.conf.d.
  The VM log lists them in that order ("Using config directory" then
  "Using system config directory"). `Driver` is correct either way.
- (C) `cmp` (diffutils) and `install` (coreutils) are present on every
  Fedora install.

## Test coverage
- `tests/lib/drivers-cases-laptop.sh` runs against a throwaway git repo with
  two committed versions, so the real file_matches_history runs. Covered:
  installed only on a laptop, with its row; a re-run is a no-op; desktop
  and VM get nothing; dry run; an unedited older copy is replaced; an edited
  copy is kept; an unclaimed file is kept and not claimed; a round trip
  through `uninstall_sysfiles`; a failed write (skipped as root).
- `tests/uninstall-sysfiles.sh`: current and older shipped copies are
  removed, an edited one is kept and named, already gone is fine, dry run.
- `tests/doctor.sh`: laptop missing (warn), dots' own copy (exact detail),
  edited copy (ok, "edited by you"). The sandbox now seals
  `DOTS_XORG_CONF_DIR` and `cmp`.
- Mutations: 9 of 9 caught, plus a SYSFILE field-order swap caught by the
  round trip. Full suite exit 0 (65 scripts). Lint passed. Reviewer READY.
- **Real Xorg, f44 VM:** the user copied the snippet to /etc and logged in
  again. Xorg 1.21.1.24 parsed it with no parse error and the session came
  up. The section matched no device (the VM has no touchpad). The only (EE)
  lines are fbdev/vesa, identical in the previous session's log.
- Not verified: a real touchpad (VM only).

## Follow-ups
- scope-h slot 5: `laptop-power` (tuned-ppd plus a profile switcher).
- Deviations: tests/lib/drivers-cases-laptop.sh (a 250-line split) and
  tests/lib/doctor-sandbox.sh were outside the plan's Scope.
