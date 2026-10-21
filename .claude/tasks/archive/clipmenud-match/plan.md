# Plan — clipmenud-match

## Goal
Void's /usr/sbin/clipmenud starts `#!/usr/bin/env bash`, so its process is
named "bash": `pkill -x clipmenud` in dots_session_end never matched (an
orphan clipmenud held ly's tty2 after logout on the VM, 2026-10-21) and
autostart's `pgrep -x clipmenud` guard never saw a running copy. Match it as
dwm-nightlight is matched: `-f '/clipmenud$'`. Existing ~/.xinitrc files with
the old line are told to replace it.

## Scope
- scripts/install-session.sh
- scripts/install-session-template.sh
- scripts/install-session-report.sh
- scripts/install-session-report-xinitrc.sh
- docs/THEMING.md
- tests/session-end-match.sh
- tests/xinitrc-report.sh
- tests/xinitrc-theme.sh
- CHANGELOG.md

## Steps
1. tests/session-end-match.sh: fake env-bash clipmenud/dwm-nightlight + named binaries; every shipped stop line (pkill -> pgrep, never pkill) and the autostart guard find them. Fails first.
2. Template stop + autostart guard + report paste line + THEMING.md block -> -f '/clipmenud$'.
3. xinitrc report: the old `-x clipmenud` stop counts as stale; paste the replacement only.
4. Update xinitrc-report/xinitrc-theme expectations; CHANGELOG.
5. VM: log in/out, no clipmenud left.

## Out of scope
- Editing users' files (user-owned; report only).

## Risks
- pkill in a test hitting the live session -> pgrep only, fakes in mktemp.
- pgrep -f matching its caller -> literal `$` in the pattern, as dwm-nightlight.
