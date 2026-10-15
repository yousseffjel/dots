# void-i8-runtime — I-8: runtime scripts and doctor on Void

## What changed
- `config/dwm/bin/dwm-powermenu`: suspend, reboot and poweroff go through
  elogind's `loginctl`.
- `suckless/dwmblocks/scripts/dwm-updates`:
  - the count is the `update` lines of a local `xbps-install -nu` (no -S,
    no network); `install` lines are new dependencies, not updates;
  - any non-zero exit shows n/a;
  - right-click runs `sudo xbps-install -Su`.
- `config/dwm/bin/dwm-power`, `dwm-brightness`: power-profiles-daemon in
  place of tuned-ppd, and the video group in place of logind (comments and
  messages).
- `config/theme/templates/always/fastfetch.dcol`: the logo is "void".
- `scripts/doctor-checks.sh`: new check_groups (D4), reading
  install-services-groups.sh's USER_GROUPS:
  - skip when the group does not exist;
  - warn when the user is not in it;
  - warn when the user was added but this session predates it;
  - skip once when `id -un` fails.
- Comment-only Fedora → Void fixes: mimeapps.list, alacritty, the xorg
  touchpad snippet, dwm-emoji, dwm-colorpicker, dwm-lock, sxhkdrc,
  config.def.h, the four theme.conf files. KEYBINDINGS.md updated.
- Tests: blocks-info (an xbps fixture), dwm-menus, dwm-power, doctor (five
  group cases), doctor-sandbox (fake id/getent).

## Key Technical Decisions
- **The UPD count stays offline:** `-nu` without `-S`, as dnf's `-C` was.
  The count is as fresh as the last sync; Void has no makecache timer.
- **A full `-Su` from the bar**, never a partial update, matching the
  installer's every-run upgrade.
- **The doctor group check was not deferred.** It reuses the services
  stage's list, so the two cannot drift.

## Assumptions Made
- (B) None beyond what was probed. Still to check on the VM (I-10): the
  power menu actions and the UPD count against a real outdated system.

## Test coverage
- Probed for real:
  - `xbps-install -nu`: exit 0 with nothing to do; the update line format,
    seen by downgrading a pkgdb entry in a scratch root;
  - power-profiles-daemon-0.30_1 serves org.freedesktop.UPower.PowerProfiles,
    with allow_active yes;
  - elogind-252.39_1's login1 policy: suspend/reboot/power-off
    allow_active yes;
  - fastfetch 2.69.0 lists a "void" logo.
- Mutations on a tree copy, 5/5 caught: UPD counting install lines, UPD
  syncing, the power menu back on systemctl, doctor ignoring a stale
  session, and the upgrade without a sync.
- `tests/run-tests.sh` 81 OK, 1 SKIP. `tests/lint.sh --strict` passes.
  Reviewer: WARN (id -un failure), fixed, then READY.

## Follow-ups
- I-9: CI on the void-glibc container (lint, tests, build-suckless,
  install-dry-run, install-container).
