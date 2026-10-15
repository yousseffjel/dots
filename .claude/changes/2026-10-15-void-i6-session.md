# void-i6-session — I-6: the X session without systemd user units

## What changed
- `scripts/install-session.sh`, the generated ~/.xinitrc:
  - with no session bus it re-runs itself under
    `dbus-run-session -- /bin/sh "$0" "$@"` first of all. It is not exec'd:
    exit 127 (the bus daemon could not start) falls through without a bus,
    and DOTS_BUS_TRIED stops a second try;
  - `dbus-update-activation-environment DISPLAY XAUTHORITY`, `pipewire &`,
    then dwm;
  - dots_session_end also stops wireplumber and pipewire;
  - the dots-session.target / systemctl block is deleted.
- Deleted `config/systemd/user/dots-session.target` and its deploy in
  install-restore-apps.sh.
- `scripts/install-restore-pipewire.sh` and `scripts/uninstall-pipewire.sh`
  (new): two links in `~/.config/pipewire/pipewire.conf.d`
  (10-wireplumber, 20-pipewire-pulse) to Void's
  `/usr/share/examples/...`, one `LINK pipewire <path> <target>` row each;
  uninstall removes a link only while it still points there.
- `scripts/install-session-report-xinitrc.sh` (split at the cap): the
  existing-.xinitrc report.
  - Session marker: `dbus-run-session`. A Fedora-era file (no bus, or with
    dots-session.target) gets the full two-part block.
  - A missing PipeWire stop gets its own lines.
- `scripts/doctor-portal.sh`: checks the session bus, then the portal.
- Tests:
  - xinitrc-theme and xinitrc-report rewritten for the session;
  - new pipewire-config;
  - symmetry: fixture examples, plus check_specific_claims moved into
    tests/lib (cap);
  - doctor, doctor-sandbox (FAKE_NOBUS) and cursor-x11 updated.
- Docs: THEMING.md § Desktop portal rewritten (paste block held equal to the
  report), TESTING.md, UNINSTALL.md, CLAUDE.md rule 6 + map, CHANGELOG,
  scope.

## Key Technical Decisions
- **dbus-run-session re-run** rather than a session manager: Void ships no
  xinitrc.d snippet that starts a bus, and ly 1.4.1's setup.sh starts none
  (both read).
- **Portal via plain D-Bus activation:** its .service files carry `Exec=`
  (read in xdg-desktop-portal-1.22.1_1), so no unit is needed. DISPLAY is
  handed over with dbus-update-activation-environment.
- **PipeWire from .xinitrc, not autostart.sh:** it holds no X connection
  and must end with the session (rule 6). The per-user config links are the
  handbook's setup, so no sudo is needed.
- **Fall through on 127, no exec:** probing the real dbus-run-session showed
  that a bus that cannot start is exit 127. With exec, that would have
  ended the session before dwm.

## Assumptions Made
- (B) `$0` is the xinitrc's path under both startx (xinit runs the client)
  and ly (its setup.sh `exec "$@"`). To be confirmed on the VM (I-10).
- (B) XDG_RUNTIME_DIR comes from elogind's PAM session (pam_elogind in ly's
  PAM file; startx via `login`). PipeWire needs it. Unverified until I-10.

## Test coverage
- Real: dbus-run-session 1.16 probed (127 when the daemon cannot start, 1
  when the program is missing, otherwise the program's status). Void package
  contents read for the portal, PipeWire and WirePlumber.
- Mutations on tree copies, 10/10 caught:
  - template: no re-run, no PipeWire stop, no DISPLAY hand-off, PipeWire
    never started, the 127 fallback dropped;
  - report keyed on the old marker;
  - no LINK row;
  - uninstall removing a re-pointed link;
  - doctor blind to no bus;
  - restore never linking.
- `tests/run-tests.sh` 81 OK, 1 SKIP. `tests/lint.sh --strict` passes.
  Reviewer READY, then READY again after the 127 fallback.

## Follow-ups
- I-7: drivers + VM detection (systemd-detect-virt, tuned →
  power-profiles-daemon, drivers_pkg → pkg_ensure).
- I-10: confirm sound, the portal's dark mode and `$0` on a real Void VM.
