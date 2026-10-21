# ci-dwm-runtime-red
Date: 2026-10-06
Files: 5 (plus slot state) | Lines: +64/-47 excluding state

## What changed
- `.github/workflows/ci.yml`: `procps-ng` added to the "Install dwm-runtime.sh
  test dependencies" line, and the "Run dwm under Xvfb" comment now records
  why it is there.
- `tests/dwm-runtime.sh`:
  - `pkill` is a skip prerequisite, like Xvfb and xterm;
  - `cleanup()` runs `set +e`, so teardown can no longer replace the exit
    status;
  - the unused `warn()` helper is gone, and the header and the final message
    describe restartsig as a hard check.
- `tests/lib/dwm-runtime-checks.sh` `check_restartsig`:
  - deletes root `_NET_SUPPORTING_WM_CHECK`, sends SIGHUP, sets a throwaway
    `_DOTS_TEST_WAKE` root property, then waits for the check property to
    come back;
  - the three `warn` calls are now `fail`;
  - the post-restart `pgrep` re-detection is removed, since execvp keeps the
    PID.
- `TESTING.md` (four patches; procps-ng; why restartsig was advisory) and
  `CHANGELOG.md` (Fixed).

## Why
Asked "what is next", I checked CI through the public GitHub API: CI on main
had been red since 2026-09-08, the first push after `tests/dwm-runtime.sh`
landed. The last green run was 97c3dbb on 2026-08-14, and nothing was pushed
in between. Every run failed at build-suckless "Run dwm under Xvfb", on both
images, with exit 127 (job logs need auth; the check-run annotations are
public).

Reproduced in a `fedora:latest` container. Every check passed, then the EXIT
trap's `pkill` was "command not found". `set -e` is live inside an EXIT trap,
so 127 became the exit status.

The same run showed the restartsig section had never passed, for two reasons:
- **No wake-up event.** dwm's `sighup()` only clears `running`, and `run()`
  blocks in `XNextEvent()`. A real desktop always has events (status-bar
  PropertyNotify), but the test sent none. The old comment blamed signal
  delivery in the sandbox, which was wrong.
- **Unreliable detection.** The detector compared check-window IDs. After
  execvp the old X connection closes and the new one usually reuses the
  client slot, so the ID repeats: the event fix alone passed 1 run in 3.

## Key Technical Decisions
- **Delete before the HUP, wake separately.** Deleting after the HUP was the
  first version. The reviewer found the race: a stray event could restart dwm
  first, and the delete would then remove the new instance's property, a false
  FAIL. With delete → HUP → wake, a stray event only makes the restart happen
  sooner.
- **Promoted restartsig from WARN to FAIL**: the plan's step 5 required 3
  consecutive passes; it got 5/5 on fedora:latest, then 3/3 per image on the
  final tree.
- **procps-ng stays CI-only**, out of `build.lst`, for the same reason as the
  other test tools. A real install already gets it from `desktop.lst`.

## Assumptions
- none. Every claim was reproduced in a container or read from the CI API.

## Test coverage
- `tests/run-tests.sh`: 41 OK, 0 FAIL. dwm-runtime.sh skips on the dev host
  because there is no built dwm. `tests/lint.sh` is clean.
- Containers, running the CI steps on a copy of the tree:
  - unfixed tree: exit 127 (reproduced);
  - final tree: 3/3 exit 0 on each of fedora:latest and fedora:43;
  - mutant dwm with a no-op `sighup()`: FAIL "never came back", exit 1, on
    both images.
- Known insensitivity: a mutant without the property delete passed, because
  `spawn_win`'s MapRequest also wakes dwm. The border-colour assertion is what
  proves the reload.
- Audit: Medium+ tier, 1 issue fixed (the red-since date). Reviewer: WARN,
  fixed, then READY.

## Follow-ups
- After merging and pushing, confirm the GitHub CI run on main is green. That
  also settles the MASTER_PLAN queue item "Watch the first CI run after
  2026-08-10": lint has passed throughout, and build-suckless gets its first
  green run since the dwm test was added.
- Still open from the test header: windows recovered by `scan()` after a
  restart lose dwm's selected client. Not investigated.
