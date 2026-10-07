# Plan — xinitrc-clipmenud-cleanup

## Goal
Logging out of dwm leaves clipmenud looping on the ly TTY (clipnotify + xsel
fail instantly once X is gone, and the loop never sleeps). ~/.xinitrc must stop
the user's clipmenud/clipnotify when the session ends, on both the systemd and
the no-systemd path (Option A, chosen by the user 2026-10-07).

## Scope
- scripts/install-session.sh
- scripts/install-session-report.sh
- tests/xinitrc-theme.sh
- docs/THEMING.md

## Allowed
- scripts/install-session.sh
- scripts/install-session-report.sh
- tests/xinitrc-theme.sh
- docs/THEMING.md

## Forbidden
- scripts/install-session-template.sh

## Steps
1. Template: one EXIT trap for every path — pkill clipmenud/clipnotify, then stop dots-session.target only if it was started; `exec dwm` becomes a plain `dwm`.
2. Report: an existing ~/.xinitrc lacking the cleanup gets the (updated) session block as paste lines.
3. Docs: THEMING.md § Desktop portal paste block matches the new lines.
4. Test: assert cleanup on systemd / no-systemd / start-fails / HUP paths, and the report for a 2026-10-06 file.
5. Verify: bash -n, shellcheck, tests/xinitrc-theme.sh, tests/lint.sh.

## Out of scope
- Other daemons (they all hold an X connection and die with X).
- Verifying on the VM (no ssh key on this host) — left as a next step.

## Risks
- pkill -u kills a second concurrent X session's clipmenud — single-seat desktop; documented.
- Paste block drifts from template — test holds report == docs.
