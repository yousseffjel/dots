# theming-reload
Date: 2026-08-05
Files: 1 (scripts/theme/reload.sh, new) | Lines: +211

## What changed
- Added `scripts/theme/reload.sh [--quiet]` — sub-task 5/7, the single
  reload entry point. Two phases, in this order:
  1. `xrdb -merge $cacheDir/xresources`, **alone and first**. Every
     consumer below re-reads its colors from the X resource database, so
     signalling them before the merge would have each pick up the
     *previous* palette.
  2. Then, concurrently: `kill -HUP` dwm (restartsig re-execs it),
     `pkill -USR1 st` (in-place, keeps shells alive), restart dwmblocks,
     kill dunst (D-Bus reactivates it), `pkill -USR1 picom`, re-run
     `~/.fehbg`.
- Every step guards on installed/running and skips with a log line; a
  failing step never aborts the run. No `DISPLAY` exits 0 cleanly — the
  normal case when the installer runs before `startx`.
- Concurrency-safe: the whole script serializes on a `flock`, since it is
  bound to a hotkey and back-to-back invocations are the normal case.
- Hang-safe: `xrdb` and `~/.fehbg` are wrapped in a 10s `timeout`.

## Why
Sub-task 5 of `.claude/tasks/scope-a-theming-engine.md`. Templates write
files; nothing re-reads them until something signals the running apps.

## Key Technical Decisions
**Serialize the whole script, not just the racy helper.** The reviewer
found a TOCTOU in the dwmblocks kill/restart that could leave two
instances alive under simultaneous invocations. Locking the entire
reload rather than patching that one helper also rules out interleaved
`xrdb` merges, which would be a subtler version of the same bug.

**Hold the lock on an explicit fd, never via `exec flock ... "$0"`.**
This is the single most important detail in the file and is commented as
such. The re-exec form leaks its lock fd into *every* descendant —
including the detached, long-lived `setsid dwmblocks` daemon, which then
holds the lock for its entire lifetime. The failure mode is nasty: the
first reload works, and every subsequent one blocks for the full 30s
timeout and then silently fails. Holding our own fd lets
`reload_dwmblocks` close it in that one spawn via `{LOCKFD}>&-`.

**Only `xrdb` and `~/.fehbg` are timeout-wrapped.** `kill`/`pkill`/
`setsid` return immediately and cannot hang; wrapping them would add
noise for no benefit. Those two can: `xrdb` blocks on a wedged X server,
and `~/.fehbg` is an arbitrary user-owned script.

**dunst is killed, not restarted.** It is D-Bus activated, so the next
notification respawns it against the regenerated `dunstrc`; starting it
here would race that activation.

## Assumptions
- **Type B** — on lock-acquire timeout (30s) the run exits 0 with a
  warning rather than failing. A concurrent reload is already producing
  the desired end state, so failing the second one would surface an error
  for a non-problem. If incorrect: change that `exit 0` to `exit 1`.

## Test coverage
Verified by live execution, not inspection:
- All six reload paths exercised, including a compiled stub `dwmblocks`
  (a shell script that `exec`s something else is invisible to `pgrep -x`).
- Ordering: `xrdb` completes before any helper starts; merged values
  confirmed present via `xrdb -query`.
- Parallelism is real: ~200-280% CPU, ~0.05s wall.
- Graceful degradation: no `DISPLAY`; no xresources file yet; each target
  absent and present; a *failing* step still exits 0 despite `set -e` +
  bare `wait`.
- Hang guard: a `~/.fehbg` that sleeps 600s bounds the run at 10s.
- Locking: two simultaneous invocations serialize (6s for a 3s step, not
  3s); four rapid-fire reloads leave exactly one dwmblocks.
- Lock-fd hygiene: the respawned daemon's `/proc/<pid>/fd` shows only
  0/1/2, and `lslocks` shows nothing holding `.reload.lock` afterwards.
- Degraded lock paths: flock absent, lock file unwritable, cacheDir
  read-only, cacheDir uncreatable, lock path replaced by a directory or a
  symlink — all degrade to unlocked, exit 0, and emit nothing on stderr.

### Bugs found and fixed during review
1. **Unbounded `wait`** (reviewer, pass 1). A hung helper blocked the bare
   `wait` forever with no escape hatch. Fixed with `run_bounded`.
2. **dwmblocks TOCTOU** (reviewer, pass 1). Fixed with the whole-script
   lock.
3. **Lock fd leaked into the dwmblocks daemon** (reviewer, pass 2) — a
   regression introduced by fix 2 and strictly worse than the bug it
   replaced, because it only manifests on the *second* invocation. Fixed
   with the explicit-fd pattern above.
4. **`mkdir -p "$cacheDir"` hard-aborted under `set -e`** when cacheDir
   did not exist and its parent was unwritable (reviewer, pass 3),
   contradicting this script's never-fail contract. This also corrected an
   overbroad claim of mine — I had only tested an unwritable cacheDir that
   *already existed*.
5. **Bash redirection-order leak** (found while verifying fix 4). In
   `: >>"$lock" 2>/dev/null` bash applies redirections left to right, so
   the "cannot open" message escaped to the real stderr before stderr was
   silenced. Fixed by putting `2>/dev/null` first.

Reviewer verdicts across three passes: WARN -> BLOCK -> WARN, each
addressed above. The reviewer also resolved a race I flagged but could
not settle myself: dwm re-execs while dwmblocks is concurrently
restarted, and dwm locates dwmblocks by `pidof -s dwmblocks` for
statuscmd click routing — reading `getstatusbarpid()` confirmed dwm
self-revalidates the pid, so a stale pid is harmless.

## Follow-ups
- Sub-task 6's `wallpaper.sh`/`theme-apply.sh` call this as their last
  step.
- Sub-task 7 should note in `docs/THEMING.md` that block scripts pick up
  new colors only on dwmblocks restart (they read the palette at exec
  time), which is why `reload_dwmblocks` restarts rather than signals.
