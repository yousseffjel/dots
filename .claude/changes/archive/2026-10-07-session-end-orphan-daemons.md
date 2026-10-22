# session-end-orphan-daemons
Date: 2026-10-07
Files: 9 (+ task folder) | Lines: +200/-89 (most of the 89 are the report section moved out of tests/xinitrc-theme.sh)

## What changed
- `scripts/install-session.sh`: the generated `~/.xinitrc`'s `dots_session_end`
  also runs `pkill -u <uid> -x dwmblocks` and
  `pkill -u <uid> -f '/dwm-nightlight daemon$'` (the daemon's own
  `DAEMON_PATTERN`). The comment explains which autostart daemons outlive X.
  `session_xinitrc_template` is now two parts (`_theme`, `_session`) for the
  60-line function cap. It was already 64 lines at HEAD, after the cursor-theme-x11
  merge line. The generated file was diffed against HEAD's: only the intended
  lines differ.
- `scripts/install-session-report.sh`: a fifth marker (`pkill.*dwmblocks`). An
  `.xinitrc` with a session-end step but no dwmblocks stop gets the updated
  session paste block, which now carries both new lines.
- `docs/THEMING.md` § Desktop portal: the same two lines and why they exist.
- Tests: `tests/xinitrc-theme.sh` expects the two new pkills on every exit
  path. Its report section moved to a new `tests/xinitrc-report.sh` at the
  250-line cap. That file also gained a pre-dwmblocks case and a check that
  the template's `pkill -f` pattern equals `dwm-nightlight`'s
  `DAEMON_PATTERN`.
- `CLAUDE.md` rule 6, `TESTING.md`, `CHANGELOG.md` (Fixed).

## Why
User report from the Fedora VM: after logging out and back in, the bar showed
`dwm-6.8` (no status text). It was fine after `dots theme dark`. dwmblocks is an X client
that sleeps and writes the root name only when a block changes, so it notices
the dead X server only on its next write and survives logout for up to a
block interval. autostart.sh starts it only `if ! pgrep -x dwmblocks`, so a
quick re-login finds the old one, starts none, and the old one then dies.
`dwm-nightlight daemon` is a shell loop with no X connection and a pgrep-based
single-instance check. It has the same flaw, permanently: night light silently
stops after a re-login. Every other autostart daemon blocks on its X connection
and exits when X closes. clipmenud was already handled the same way earlier
today.

## Assumptions
- Type B: diagnosis reasoned from the code (dwmblocks `setroot` writes only on
  change; autostart's pgrep guards), not reproduced on the VM. The user
  confirmed the timing (broke after logout+login, not after a theme apply).
- Type B: stop in the session end rather than loosening autostart's guards.
  Alternative considered: `pkill` then start in autostart.sh. Rejected because
  autostart.sh is user-owned on existing installs and re-runs on every dwm
  restart. The session end is the established mechanism (rule 6).
- Type C: the floating tray icons in the same screenshot are out of scope;
  their cause is unknown.

## Test coverage
- `tests/run-tests.sh`: 43 OK, 1 SKIP (`dwm-runtime.sh`, no built dwm on the dev
  host). `tests/lint.sh` passes.
- Mutation on scratch copies with a passing unmutated control. All six were
  caught: the template dropping the dwmblocks pkill, the template's night-light
  pattern drifting, `DAEMON_PATTERN` drifting, the report never flagging a
  missing dwmblocks stop, the paste block lacking the dwmblocks line, and
  `THEMING.md` lacking the night-light line.
- Not tested: a real logout/login on the VM.

## Follow-ups
- On the VM: paste the two pkill lines into `dots_session_end`, log out and
  quickly back in, and confirm the bar comes back.
- The floating tray icons seen in the same screenshot: identify their owner
  (`xprop`) if they recur after this fix.
