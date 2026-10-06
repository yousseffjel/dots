# portal-session-target
Date: 2026-10-06
Files: 15 tracked + 2 new | Lines: +229/-22 tracked, +79 in the new files

## What changed
- `config/systemd/user/dots-session.target` (new) has
  `BindsTo=graphical-session.target` and `Wants=`/`After=`
  `graphical-session-pre.target`. `systemd-analyze --user verify --man=no`
  passes.
  - `install-restore-apps.sh` deploys it with `deploy_app_file` to
    `~/.config/systemd/user/`, as an APP row.
  - It is copied, never linked, because that directory holds the user's own
    units.
- `session_xinitrc_template` (`install-session.sh`) runs after the xinitrc.d
  loop:
  - `systemctl --user import-environment DISPLAY XAUTHORITY`, then
    `daemon-reload`, then `start dots-session.target`;
  - on success, `trap` stop on `EXIT`, `trap 'exit 0' HUP INT TERM`,
    `dwm; exit 0`;
  - with no systemctl or any failure, the old `exec dwm`.
- `session_xinitrc_report` (`install-session-report.sh`) checks two markers
  independently: `dots/theme` and `dots-session.target`.
  - A missing piece gets its own paste block: `session_xinitrc_report_theme`
    or `session_xinitrc_report_session`.
  - The pre-existing 64-line `session_autostart_report` was split at the
    lxpolkit boundary into `session_autostart_report_more` (60-line cap).
- `scripts/doctor-portal.sh` (new), wired into `doctor.sh` after
  `check_theme`:
  - `check_portal` checks `systemctl --user is-active
    graphical-session.target`. When it is not active, the warning depends on
    whether `~/.xinitrc` already names `dots-session.target`: "log out and
    back in" if it does, "add the lines in docs/THEMING.md" if not.
  - `check_portal_answers` makes a real
    `gdbus … Settings.ReadOne org.freedesktop.appearance color-scheme`:
    `uint32 1` is ok, any other value warns, an error warns and is quoted.
  - It skips without X, systemctl or gdbus.
  - The dconf line in `doctor-session.sh` now says the preference is
    *stored*, not that "apps are asked for dark mode".
- Tests:
  - `tests/xinitrc-theme.sh` runs the generated file with a fake `systemctl`.
    Covered: start, dwm, stop; a failed start still runs dwm; a HUP from a
    dying X still stops the target.
  - It also checks that the unit binds graphical-session.target and is the
    file restore deploys, and covers the two-marker report (with the
    pre-portal file derived from the shipped template).
  - Every printed paste line must appear in `docs/THEMING.md`.
  - `tests/doctor.sh` gets 7 portal cases; `tests/lib/doctor-sandbox.sh` gets
    `systemctl is-active` and `gdbus` fakes.
- Docs:
  - `docs/THEMING.md` gains a "Desktop portal" section with the paste block.
  - `CLAUDE.md` gets a rule-6 note and a map row.
  - The ROADMAP portal row now says the portal only starts since this change.
  - Also updated: `docs/UNINSTALL.md` step 5, `CHANGELOG.md` (Fixed),
    `TESTING.md`.

## Why
VM, 2026-10-06: `gdbus call … Settings.ReadOne … color-scheme` →
"Could not activate remote peer 'org.freedesktop.portal.Desktop': startup job
failed", and Flatpak GNOME Text Editor rendered light.
xdg-desktop-portal 1.22.1's unit (`src/xdg-desktop-portal.service.in`) has
`Requisite=graphical-session.target`, and a startx/ly + dwm session never
activates that target. So no portal had ever run in a dwm session: the
xdg-portal-gtk work (f831138) installed one that could not start.

## Key Technical Decisions
- **A session target, not a drop-in** (scope-e decision 8). A drop-in
  resetting `Requisite=` would fight upstream, would never stop at logout,
  and would leave the next unit with the same Requisite broken.
  `graphical-session.target` is `RefuseManualStart=yes` and
  `StopWhenUnneeded=yes` (systemd 262), so `BindsTo=` from our own target
  both starts it and stops it. This is the pattern sway and i3 document.
- **dwm can never be bricked.** Every systemctl step is in one `&&` chain, and
  any failure falls through to the old `exec dwm`.
- **Checked against the real systemd, not assumed.** `import-environment` of
  an unset variable prints "not set, ignoring" and returns 0 (systemd 262), so
  an unset XAUTHORITY cannot silently skip the start.
- **restartsig is safe.** dwm's HUP re-exec keeps its PID and the xinitrc
  shell keeps waiting, so the target is not stopped on a theme reload.
- **Not a reversal of the dots-doctor log** ("portal check left out because
  the portal is D-Bus activated"). That decision was about looking for a
  running process. This change asks the portal over D-Bus, which is the
  activation path itself.

## Assumptions
- Type B: Fedora's `/etc/X11/xinit/xinitrc.d/50-systemd-user.sh` runs before
  our block. The explicit `import-environment` makes that irrelevant.
- Type B: ly's xinitrc session runs `~/.xinitrc` through `/bin/sh` (bash on
  Fedora), as the template header has always assumed.

## Test coverage
- `tests/run-tests.sh`: 40 OK, 0 FAIL. `tests/lint.sh` clean.
- Mutation testing on copies: 10 of 11 caught, each by its own assertion.
  - Caught: target never started; no stop on exit; no fallback `exec dwm`;
    session marker ignored; unit not deployed; BindsTo dropped; doctor ignores
    the target state; doctor accepts any reply; check_portal unwired; doc
    paste line drifts.
  - **Survived: dropping `trap 'exit 0' HUP INT TERM`.** On bash (Fedora's
    /bin/sh) the EXIT trap already fires on a fatal HUP, so the line only
    matters for strict POSIX shells such as dash. It is kept, and the test
    says so in a comment. There is no dash on the dev host to test it.
- **Not run on a real session.** The target was never started on the dev host
  (that would activate graphical-session.target in the user's live desktop),
  and never on the VM.

## Follow-ups
- On the VM after merge:
  - run `--only-restore` to deploy the unit;
  - paste the `docs/THEMING.md` § Desktop portal block over `exec dwm` in the
    existing `~/.xinitrc`, then log out and in;
  - `dots doctor` should show `graphical-session.target is active` and `the
    desktop portal answers`, and `flatpak run org.gnome.TextEditor` should be
    dark.
- Recorded here because change logs are immutable: the VM confirmed
  gtk3-adwaita-dark-shim the same day. Native Thunar and Flatpak Mousepad
  are dark with no `GTK_THEME`, and the doctor shows `GTK3 theme Adwaita-dark
  found in ~/.local/share/themes`.
- Micro: Flatpak `exports/bin` on PATH (scope-e decision 10).
- `CHANGELOG.md` is also edited in `slot/dunst-clear-bar`, so expect a
  trivial conflict at merge.
