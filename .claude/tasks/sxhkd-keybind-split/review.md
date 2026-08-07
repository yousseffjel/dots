# Review — sxhkd-keybind-split

## Audit Loop

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 2 found / 2 fixed. `install-session.sh` was mode 644 where the identical-precedent `install-restore-theme.sh` is 755; header rewritten to state the sourced-library contract (caller provides `set -euo pipefail`, `DRY_RUN`, colour helpers) in that file's format. Reuse scan: nothing in the repo did hotkeys or screen brightness before. |
| 2 | Size/Performance | ✅ | 1 found / 1 fixed. `install_session_autostart()` came out at 69 lines, over the 60-line cap — the "already exists" branch was extracted to `session_autostart_report()`, leaving 50 / 26. All files under 250 after the step-4 split. |
| 3 | Types/Validation | ✅ | 2 found / 2 fixed. **(a)** `current()` used `raw="$(xrandr --verbose 2>/dev/null)"`; under `set -e` a failing command substitution in an assignment aborts with no message at all — verified with a standalone repro — so a dead X server made `dwm-brightness` exit 1 silently. Now captured with `|| true` and diagnosed. **(b)** `up`/`down` inlined `apply "$(($(current) + STEP))"`, which carried on with an empty reading after a failed probe and would clamp the display to MIN; replaced with `adjust()`, which returns early. No suppressions, no unquoted expansions, shellcheck clean at `-S style`. |
| 4 | Dependencies | ✅ | 0 found. Every command `sxhkdrc` invokes is either declared in `packages/extra.lst` (playerctl, pamixer, firefox, thunar, sxhkd) or ships in `config/dwm/bin/`. `pkill`/`pgrep` (procps-ng) is pre-existing — `reload.sh`, `dwm-powermenu` and three `.dcol` templates already assumed it — and is a Fedora `@core` package. dwm's Super bindings (`Shift+x`, `v`) and sxhkd's (`w`, `Shift+w`, `Ctrl+w`, `b`, `e`, `Ctrl+r`) are disjoint, checked against `config.def.h`.

**Audit verdict:** ✅ READY

### Incremental re-audit — step 8 (docs)

Run after `## Allowed` was extended to `docs/THEMING.md` and `CLAUDE.md`.
2 found / 2 fixed, both on my own first draft of the step:

1. **Architecture** — the draft copied the keybind table into `THEMING.md`,
   which already cross-referenced `KEYBINDINGS.md`. Two copies of the same
   table drift apart; reverted to a pointer plus the corrected claim.
2. **Validation** — both files claimed the binds are "active on install".
   `sxhkd` is in `extra.lst`, which is best-effort, so a failed install leaves
   them dead. Restated as conditional on sxhkd being installed and running.
   This is the same class of overclaim the reviewer caught in sub-task 3.

Size and dependency sweeps: 0 findings (docs only; 209 / 123 lines).

### Escalated separately (not an audit finding)

Adding the sxhkd autostart branch took `install-suckless.sh` to **253 lines**,
past `file-architecture.md`'s 250-line hard stop. Put to the user as three
options rather than self-granted as an exception; they chose the split. Lines
158–245 moved to `scripts/install-session.sh` — the same arrangement
`install-restore.sh` already has with `install-restore-theme.sh`, which its own
header records as having been created for exactly this reason. Result: 172 +
134 lines. Proven behaviour-preserving by diffing the generated `autostart.sh`
against the one HEAD produces: the only difference is the intended sxhkd block.

## Test Gate

**Command:** `tests/lint.sh && tests/pkglist.sh && tests/build.sh`
(repo convention — the three suites `.github/workflows/ci.yml` mirrors; there is
no `config.yml`, `package.json` or `Makefile` to discover one from)

**Result:** ✅ PASSED

- `tests/lint.sh` — shellcheck, `shfmt -i 4 -ci -bn -d`, markdownlint: pass.
  Covers the two new `scripts/*.sh` files and every touched `.md`.
- `tests/pkglist.sh` — format, duplicates, core/extra overlap: pass.
- `tests/build.sh` — all five suckless programs built, dwm included, with no
  new compiler warnings from the `config.def.h` comment change: pass.

Run in the slot worktree with the branch confirmed first
(`slot/sxhkd-keybind-split`), per the shell-config-verification memory. Build
artifacts stayed gitignored — `git status` shows only intended paths.

Not covered by the suites, verified by hand during `/code` (see
`progress.md`): `config/dwm/bin/dwm-brightness` is below `lint.sh`'s
`-maxdepth 2 *.sh` glob, so it was shellcheck/shfmt'd directly, and its
behaviour was exercised against a fake `xrandr` on `PATH` rather than the live
display.

## Reviewer Gate

**Verdict:** READY

**Notes:** Clean on the first round — no issues raised. Independently
re-confirmed the four things it was pointed at: the dwm/sxhkd key sets are
genuinely disjoint (`MODKEY = Mod1Mask` vs sxhkd's `super`/XF86 keys, and the
two existing `Mod4Mask` binds do not collide); the `install-session.sh` split
is behaviour-preserving and honours CLAUDE.md rule 6; `dwm-brightness` clamps
and fails sanely; and the `.zshenv` PATH claim in the `dwm-wallpaper` comment
is accurate against the actual file rather than repeating the stale
`20-path.zsh` reference it replaced.

**Round 2** (after `## Allowed` was extended and step 8 landed): READY again.
Verified the doc claims against the code rather than the prose — `super + w` /
`super + shift + w` / `super + ctrl + w` match `sxhkdrc` exactly, sxhkd is
genuinely started by the new `install-session.sh` autostart hook, and its
best-effort `extra.lst` status is correctly stated. Confirmed no remaining doc
tells a reader to uncomment theming binds in `config.def.h`, and that
`KEYBINDINGS.md`, `docs/THEMING.md`, `CLAUDE.md` and `sxhkdrc` are mutually
consistent.
