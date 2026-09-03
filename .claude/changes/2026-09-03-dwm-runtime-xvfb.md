# dwm-runtime-xvfb
Date: 2026-09-03
Files: 3 | Lines: +404 (excludes .claude/tasks/dwm-runtime-xvfb/ + state)

## What changed
- New `tests/dwm-runtime.sh` — the first test in this repo to actually
  execute the built `dwm` binary. Starts Xvfb, runs `suckless/dwm/dwm`
  against it, and asserts:
  - Real EWMH root-window state: `_NET_SUPPORTED` advertises the required
    atoms, `_NET_SUPPORTING_WM_CHECK` is self-consistent and names "dwm",
    `_NET_CLIENT_LIST` tracks a managed window.
  - **xresources** (required by locked decision 4): a colour set via
    `xrdb` before dwm starts is sampled from a live screenshot of the
    actual rendered border pixel, not asserted from source.
  - **actualfullscreen**: `alt+shift+f` sets/clears a real
    `_NET_WM_STATE_FULLSCREEN`.
  - **pertag** (required): `mfact` adjusted on one tag doesn't leak into
    another tag, and persists across a round-trip switch back.
  - **restartsig** (advisory only — see below): SIGHUP reload.
- `.github/workflows/ci.yml`'s `build-suckless` job gained a test-only
  dependency step (Xvfb, xdotool, xwininfo, xprop, xdpyinfo, xrdb, xterm,
  ImageMagick — verified against packages.fedoraproject.org, deliberately
  NOT in `packages/build.lst`, since a real install never needs a virtual
  framebuffer) and a step invoking the new test, per locked decision 3
  (extending `build-suckless` rather than a new job).
- `TESTING.md` gained a documentation bullet.

## Why
scope-d slot C (`.claude/tasks/scope-d-verification-harvest.md`), the
highest-value item from the 2026-08-24 dwm-titus comparison: "dots has
never executed dwm in a test at all."

## Assumptions
- **Type B** — restartsig (SIGHUP reload) is checked but downgraded to
  ADVISORY (a `warn()` that does not fail the build), not a hard assertion.
  Signal delivery to a backgrounded process proved unreliable in the
  interactive sandbox this test was developed in, reproduced independently
  with a plain `bash -c 'trap ... HUP; sleep 5' &` unrelated to dwm. The
  two checks locked decision 4 actually requires (xresources, pertag) are
  both hard failures with mutation-tested teeth; restartsig was "worth
  reaching," not required. If it warns on the first real CI run too, that
  is a genuine finding worth its own follow-up, not proof the check is
  worthless — filed as a follow-up below rather than removed.

## Test coverage
- `bash tests/dwm-runtime.sh` directly, and via `tests/run-tests.sh` (the
  full suite) — both green.
- **Mutation testing** (locked decision 4 requirement), full detail in
  `.claude/tasks/dwm-runtime-xvfb/review.md`:
  - xresources: neutered `xresupdate()`'s load loop → border reverted to
    the compiled-in default color → **caught**.
  - pertag: a first attempt neutered the wrong function (`toggleview()`,
    the Ctrl+tag variant the test's keybinds don't exercise) and produced
    a false-negative green run — re-targeted `view()`'s actual restore
    line → tag2 inherited tag1's adjusted mfact → **caught**. Both
    mutations reverted; `suckless/dwm/dwm.c` confirmed byte-identical to
    HEAD before commit.
- `bash tests/lint.sh --strict` — clean.
- Reviewer subagent: **READY**.

## Follow-ups
- Whether restartsig's apparent inability to re-select pre-existing
  scanned windows after a SIGHUP restart (`togglefullscr()` no-ops,
  `_NET_ACTIVE_WINDOW` appears stale) is a real dwm/restartsig gap or an
  artifact of this test's window-tracking is UNRESOLVED — see
  `.claude/tasks/dwm-runtime-xvfb/context.md` Notes. Worth its own
  investigation once restartsig's CI behavior is observed for real.
- Start scope-d slot D: install/uninstall symmetry against the manifest
  (the last slot in the Epic).
