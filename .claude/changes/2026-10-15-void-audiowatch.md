# void-audiowatch — the VOL block follows PipeWire (found in I-10)

## What changed
- New `config/dwm/bin/dwm-audiowatch`. It loops on `pactl subscribe` and
  redraws the bar's audio blocks:
  - sink events redraw VOL (`pkill -RTMIN+8 dwmblocks`);
  - source events redraw MIC (RTMIN+7);
  - server events, and every (re)connect, redraw both;
  - per-application events (sink-input, source-output) are ignored.
- Lifetime and launch behaviour:
  - It waits 30 s for the server at login and 10 s for a reconnect, then
    exits.
  - It is single-instance by command line (dwm re-runs autostart.sh on every
    restart).
  - It answers `--help` (tests/dwm-help.sh).
- Rule 6 wiring:
  - the launch line is in `session_autostart_services`;
  - the `session_report_daemon` line is in
    `install-session-report-applets.sh`;
  - `DAEMONS` in tests/autostart-daemons.sh;
  - `dots doctor`: `daemon_applies`/`daemon_skip_reason` (needs pactl).
- New `tests/dwm-audiowatch.sh`, which uses fake pactl, pkill and pgrep on a
  sealed PATH.
- Docs: CHANGELOG (Fixed), CLAUDE.md (map + rule 6), scope I-10 status.

## Why
On the Void VM the VOL block read 40% while pamixer said 100%. The VOL and
MIC blocks are signal-only (interval 0). On Void, `.xinitrc` starts PipeWire
next to dwm, so the block's first draw raced WirePlumber's restore, and
nothing signalled after it. On Fedora, PipeWire was up from systemd user
units before X, so this is a port regression. The user chose "watch PipeWire"
over a one-shot delayed redraw or a polling interval.

## Key Technical Decisions
- **Not stopped in `dots_session_end`** (a deviation from rule 6's "a non-X
  daemon belongs in that function"):
  - That function already stops PipeWire, and the watcher exits after 10 s
    without a server.
  - Adding a pkill line would add a fourth category to the existing-.xinitrc
    report, its paste lines, the THEMING.md block, and the tests that hold
    them equal, for no behavioural gain.
  - Recorded in CLAUDE.md rule 6.
- **Process substitution, not a pipeline**, for `pactl subscribe`. The read
  loop then runs in the watcher itself, which knows the subscriber's PID and
  kills it on SIGTERM. A pipeline would leave a subshell and pactl behind.

## Assumptions Made
- (B) `pactl` is present wherever PipeWire is. On Void, `pipewire` depends on
  `pulseaudio-utils` (checked on the VM with `xbps-query`), so no package list
  changed.
- (B) The 30 s start wait covers PipeWire's startup at login. If the server
  is not up by then, the watcher exits, and the next dwm restart (which
  re-runs autostart.sh) starts it again.

## Test coverage
- `tests/dwm-audiowatch.sh` covers six cases: event mapping, reconnect, a
  server that never starts, another watcher running, no pactl, and SIGTERM
  taking the subscriber down.
- Mutations ran on a scratchpad copy: 10 run, 9 caught. The survivor drops
  the `command -v pactl` guard. It is equivalent: without pactl, wait_server
  fails and the watcher exits, just after START_WAIT rather than at once.
- `tests/run-tests.sh` and `tests/lint.sh --strict`: see the audit below.

## Follow-ups
- On the VM:
  1. Add the printed line to `~/.local/share/dwm/autostart.sh` (it is
     user-owned), or delete that file and re-run `scripts/install-suckless.sh
     --skip-deps`.
  2. Re-login, and confirm the VOL block matches `pamixer --get-volume`.
- Still open in I-10: the power-actions check from the active session.
