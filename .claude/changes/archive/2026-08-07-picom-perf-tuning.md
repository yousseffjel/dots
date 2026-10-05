# picom-perf-tuning

Date: 2026-08-07
Files: 5 | Lines: +306/-63 (source only; +499/-66 incl. task folder + state)

Epic sub-task 10 of `.claude/tasks/scope-b-app-roster-finalization.md`.

## What changed

- **`config/picom/picom.conf` and `config/theme/templates/always/picom.dcol`
  retuned identically**: `shadow = false` (retiring `shadow-radius`,
  `-opacity`, `-offset-x`, `-offset-y`, `-color` and the whole
  `shadow-exclude` list), `unredir-if-possible = true`, and the removal of
  `detect-rounded-corners` and `detect-transient`. `wintypes` shrank to a
  single `tooltip` entry — every other block existed only to switch shadows
  off per window type.
- **`picom.dcol` lost its last `<wallbash_*>` placeholder.** `shadow-color`
  was the only one; dropping shadows retired it. The template is kept anyway
  (user decision) and now regenerates a file byte-identical to `picom.conf`.
- **`tests/picom-lockstep.sh` (new, 135 lines):** runs the real template
  engine against the static dark palette in a sandbox and diffs the generated
  output against `picom.conf`, ignoring comments and blanks. Also checks for
  unsubstituted placeholders and balanced braces/brackets.
- **`.github/workflows/ci.yml` gained a `tests` job** — mid-task scope
  expansion, user-approved. See Trade-offs.
- **`docs/THEMING.md`** records that picom is now a themed target in name
  only, and that the two files must be edited together.

## Why

The baseline was already sane — `backend = "glx"`, `vsync = true`,
`use-damage = true`, no blur, no rounded corners — so this was about removing
real per-frame cost, not undoing cargo-cult settings. Every change is
justified against picom v13's own documentation, which is directly applicable:
**both this host and Fedora 43/44 ship picom v13** (`13-1.fc43` / `13-1.fc44`),
and the user confirmed this machine *is* the target, so local checks are
representative rather than a proxy.

All 23 options in the previous config were verified still valid in v13 — none
had bit-rotted.

## Assumptions

- **(Type B) Shadows dropped entirely** (user choice of three). The largest
  constant per-frame cost once blur is already off, and on a tiling dwm
  desktop windows rarely overlap enough for shadows to earn it.
- **(Type B) `unredir-if-possible = true` with no delay** (user choice of
  three). Upstream states plainly it is "known to cause flickering when
  redirecting/unredirecting windows"; that was accepted deliberately — the
  flicker is one frame entering or leaving fullscreen, the saving is every
  frame in between. If a specific window ever misbehaves, picom v13's WINDOW
  RULES `unredir` key is the escape hatch; `unredir-if-possible-exclude` is
  discouraged upstream.
- **(Type B) `picom.dcol` kept despite having no placeholders** (user choice
  of three, against my recommendation to delete it). Preserves the engine's
  uniform shape — every deployed config still has a template behind it — at
  the cost of keeping the divergence hazard alive. Hence the test.
- **(Type C) `xrender-sync-fence` not added.** It is an NVIDIA
  tearing/corruption workaround with a measurable cost elsewhere, and the
  target is Intel UHD Graphics 770 on i915. A static config file cannot gate
  it per-driver, so this had to be settled by asking rather than inferring.
- **(Type C) `detect-client-opacity` and the 1.0 opacity trio kept.** The
  opacities restate defaults and cost nothing at runtime; `detect-client-opacity`
  costs one property read per window but is what still lets an application
  make *itself* translucent. Removing it would change behaviour, not just cost.

## Trade-offs

**DEVIATION — `.github/workflows/ci.yml` moved into Allowed.** Surfaced at
step 5 and resolved by the user. CI lints `tests/*.sh` but has never executed
them: the workflow re-implements the build and package checks inline instead
of invoking `tests/build.sh` / `tests/pkglist.sh`. So the lockstep test would
have been linted and never run, making step 3's "drift is a hard test failure"
true only for whoever remembered to run it. The new `tests` job runs every
`tests/*.sh` by glob, so tests added later are picked up automatically.
`build.sh` and `lint.sh` are skipped **by name with the reason printed** —
the first needs the X11 toolchain (covered by `build-suckless` in a Fedora
container), the second needs shellcheck/shfmt/markdownlint (covered by
`lint`). Running them unconditionally on ubuntu-latest would have made the job
red from the first push. This also means those three pre-existing tests have
never run in CI either; only the two dependency-free ones do now.

**The lockstep hazard is guarded, not removed.** Keeping `picom.dcol` means
`picom.conf` and the template must still be edited together by hand. The test
turns drift into a red build instead of a silent revert weeks later, but it
cannot stop someone editing one file.

**`detect-transient` came out during the audit, not the plan.** It groups
windows via `WM_TRANSIENT_FOR` so a group counts as focused together — which
only changes rendering if focus does. Here it cannot: `inactive-opacity`
equals `active-opacity`, and there is no `inactive-dim` or `focus-exclude`.
It was reading a property per window to feed a decision with no output. Same
reasoning that had already removed `detect-rounded-corners`.

## Test coverage

- `tests/lint.sh`, `tests/pkglist.sh`, `tests/picom-lockstep.sh`,
  `tests/build.sh` — all exit 0. `build.sh` is pure regression (no C touched).
- **Six mutants against the lockstep test, all caught:** shadow re-enabled in
  `picom.conf` only, unredir disabled in the template only, `vsync` dropped
  from the template only, an extra setting added to `picom.conf` only, an
  unbalanced brace, and an unresolved placeholder. Re-run after the
  `set -uo` → `set -euo` audit fix, since `-e` can abort early and mask a
  failure path. One mutant went stale when `detect-transient` was removed and
  was retargeted — the harness's own no-op detector caught that.
- **The new CI job was executed, not just written:** its `run` block was
  extracted from the YAML and run directly. Green path skips `build.sh` and
  `lint.sh` with reasons and passes the other two (rc=0); against a
  deliberately drifted `picom.conf` it exits 1.
- **Safety verified, and it mattered.** Running the whole `always` template
  group would fire every post-command, three of which act on the live session
  regardless of environment: `dunst.dcol` runs `pkill -x dunst`,
  `statusbar.dcol` runs `pkill -x dwmblocks`, `xresources.dcol` runs
  `xrdb -merge`. `pkill` matches by process name system-wide, so env isolation
  cannot contain it. The test points the engine at a throwaway tree holding
  only `picom.dcol`, with a fake `pkill` first on `PATH`. dunst kept the same
  PID across roughly seven engine invocations, and `~/.config/picom/picom.conf`
  was never touched.

**Not covered:** picom itself has never parsed this config. It is not running
on this box, so launching it would composite over the live session, and with
`DISPLAY` pointed at a dead server picom bails at "Can't open display" before
reading the file — no Xvfb or Xephyr available either. Every option was
checked against the v13 man page and the braces balance, but "picom accepts
this" is confirmed at the next login.

## Follow-ups

- **`tests/build.sh` and `tests/lint.sh` still never run in CI.** The new
  `tests` job skips them deliberately, and the workflow's own inline
  reimplementations are what actually run. Making the dedicated jobs invoke
  the scripts instead would remove the duplication and the risk of the two
  drifting — a separate task, since it changes jobs this one did not touch.
- **`config/picom` could arguably be symlinked now.** It is copied because
  the theming engine rewrites it, and that is still true — but the generated
  content is now identical to the repo copy, so the reason is thinner than it
  was. Not acted on: the engine genuinely does write the file, and CLAUDE.md
  states the rule plainly.
- **Verify on the target:** that picom starts cleanly with this config, that
  fullscreen unredirection engages, and how noticeable the flicker is in
  practice. If it grates, `unredir-if-possible-delay` is a one-line change to
  both files.
