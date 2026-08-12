# Plan — udiskie-autorandr

## Goal
Man two unmanned ROADMAP §3 rows: udiskie auto-mounts media without Thunar
resident, autorandr re-applies a display profile on hotplug. Scope C sub-task 3.
No systemd unit — Forbidden enforces it.

## Scope
- packages/desktop.lst
- scripts/install-session*.sh
- tests/autostart-daemons.sh
- CLAUDE.md

## Allowed

## Forbidden
- scripts/install-services.sh
- scripts/uninstall_steps.sh

## Steps
1. Declare `udiskie` + `autorandr` in `desktop.lst` with consequence comments.
2. Split `session_autostart_daemons()` FIRST (57/60); test must need no change.
3. Add udiskie to the daemon set (`command -v` + `pgrep -x`, backgrounded).
4. Add `autorandr --change` — a one-shot; decide explicitly how the test's
   backgrounded-command detector treats it.
5. Paired report branches for both in `install-session-report.sh`.
6. Roster 7 -> 9; mutant-confirm an unpaired entry still fails.
7. CLAUDE.md; full suite + `tests/lint.sh --strict`.

## Out of scope
- Any systemd unit (Forbidden enforces it); sub-task 4's dwm-* scripts.

## Risks
- autorandr is NOT installed locally and Fedora pages list no files, so its
  udev/XDG hooks stay assumed — say so in the log. udiskie IS local, so verify.
- Its XDG autostart file will not fire (dwm runs no session manager) — that is
  why step 4 exists; same precedent as polkit-gnome.
- A `--user` unit would not round-trip: uninstall disables SERVICE rows with
  `sudo systemctl disable`. Hence no systemd this slot.
- The split must keep autostart-daemons.sh passing untouched — it RUNS the
  function rather than parsing it.
