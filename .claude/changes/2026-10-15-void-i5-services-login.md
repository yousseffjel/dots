# void-i5-services-login — I-5: runit services, groups, ly built from source

## What changed
- `scripts/install-services-runit.sh` (new):
  - links dbus, elogind, NetworkManager and bluetoothd into /var/service,
    one SERVICE row each;
  - unlinks dhcpcd and wpa_supplicant only once NetworkManager is enabled
    (SERVICEOFF rows);
  - the dirs are overridable (DOTS_RUNIT_SV / DOTS_RUNIT_SERVICE).
- `scripts/install-services-groups.sh` (new): one `usermod -aG` for network,
  bluetooth and kvm, skipping groups that don't exist. Never reverted (D4).
- `scripts/install-services-ly.sh` (new):
  - ly v1.4.1 pinned to commit afb1dc6, vendor.tar.zst and the zig 0.16.0
    tarball pinned by sha256, downloaded with xbps-fetch;
  - builds as the user into a staging dir, then sudo-places each path with a
    `LYBUILD ly <path>` row;
  - `ly_take_tty2` hands tty2 to ly, never leaving it without a login.
- `scripts/install-services.sh`: wired to the three modules; the systemd ly
  block is gone.
- `scripts/uninstall-runit.sh` (new): runit uninstall_services (unlink, then
  re-link, removing a down file only if dots made it) and
  uninstall_ly_build. The old systemctl version is removed from
  uninstall_steps.sh.
- `scripts/install-pre.sh`: hard stop when not in wheel (D4).
- `scripts/doctor-checks.sh`: check_services reads runit links.
- `packages/build.lst`: + pam-devel, libxcb-devel, zstd.
- Tests:
  - new: services-runit, services-stage, ly-build, ly-pins, user-groups;
  - updated: install-pre, login-shell-path, doctor;
  - removed: uninstall-services.
- Docs: UNINSTALL.md, the CLAUDE.md map, the installer header, CHANGELOG,
  scope.

## Key Technical Decisions
- **ly v1.4.1, not v1.5.0.** 1.4.1 keeps every config.ini key ly-theme.sh
  writes, and powers off with /sbin/shutdown, which runit provides. 1.5.0
  drops hide_version_string and the *_cmd keys, and master has moved to
  config.lua.
- zig 0.16.0 (ly 1.4.x's minimum), from the official tarball pinned by
  sha256, used for the build only (user decision). Void's packaged zig is
  0.13.0.
- The ly tag is pinned by commit, not archive checksum: Codeberg generates
  archives on the fly.
- The build runs offline from the release's vendor.tar.zst (zig-pkg/).
- xbps-fetch rather than curl: it ships with xbps, so no new dependency.
- tty2 handover safety (reviewer BLOCK): nothing happens unless /etc/sv/ly
  exists; the getty goes first, and comes straight back if ly cannot be
  linked.
- polkit and udisks are not runit services: they are D-Bus activated
  (checked in the packages).

## Assumptions Made
- (B) The services stage's immediate NetworkManager takeover (dhcpcd off)
  can blip the network on a box installed over ssh. It runs last, after
  every download.
- (B) A ly pin bump on an existing install is not handled: ly_install skips
  once our binary exists. A later rebuild path is needed for that.

## Test coverage
- Real: ly v1.4.1 built with zig 0.16.0, offline, into a staging dir on the
  dev host; the file list, runit service and PAM file were read from it.
  Void .xbps contents read for:
  - base-files (groups), bluez (bluetooth group + D-Bus policy);
  - NetworkManager (polkit rule granting group network, run script);
  - elogind (run script), polkit/elogind D-Bus activation files.
  xbps-fetch: exit 1 on a 404, no partial file.
- Mutations on tree copies, 12/12 caught (10 first, then the two tty2
  guards).
- `tests/run-tests.sh` 80 OK, 1 SKIP. `tests/lint.sh --strict` passes.
  Reviewer: BLOCK (tty2 could be left without a login), fixed, then READY.

## Follow-ups
- I-6: session (.xinitrc without systemd user units: D-Bus session,
  pipewire, portal).
- A rebuild path for a ly pin bump.
- The VM must prove the login end to end (I-10).
