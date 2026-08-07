# Review — lock-idle-xss-lock

## Audit Loop

Tier: **Medium+** (6 files, +219/-24 — `git diff --shortstat HEAD` undercounts
by 130, since `config/dwm/bin/dwm-lock` is untracked).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 found, 0 fixed — `procps-ng`/`pgrep` is undeclared in `packages/*.lst`. Pre-existing (`autostart.sh` already used `pgrep` for dwmblocks/clipmenud/sxhkd) and `packages/` is Forbidden by this plan, so it is recorded as a follow-up rather than fixed. |
| 2 | Size/Performance | ✅ | 0 found — dwm-lock 140, dwm-powermenu 31, install-session.sh 159, all under the 250 cap. Longest function 24 lines. `LOCK_SECS`/`DPMS_OFF_SECS` are named constants; no magic numbers. |
| 3 | Types/Validation | ✅ | 1 found, 1 fixed — extra arguments were silently ignored, so `dwm-lock --daemon --transfer-sleep-lock` would have run the daemon and dropped the flag without a word. Since the file's own header explains why that flag is absent, the mistake is realistic. Added an arity guard plus 6 assertions. |
| 4 | Dependencies | ✅ | 0 found — no dead functions (all 8 verified in use), no circular sourcing, `install-session.sh`'s sourced-by-`install-suckless.sh`-only contract unchanged. |

**Audit verdict:** ✅ READY

### Notes carried out of the sweeps

- **No command substitutions exist anywhere in `dwm-lock`**, so the
  `var="$(cmd)"`-aborts-silently-under-`set -e` class that bit sub-task 4
  twice is structurally absent here rather than merely avoided.
- **`dwm-powermenu` fails `shfmt` at HEAD and still does.** Its aligned `case`
  arms are the file's own style and predate this change (verified against
  `git show HEAD:`), so the alignment was matched, not reformatted. The file
  is outside `tests/lint.sh`'s `-maxdepth 2` glob, which is why the drift
  survives.

## Test Gate
**Command:** `bash tests/lint.sh && bash tests/pkglist.sh && bash tests/build.sh`
(repo convention — nothing auto-detectable, no `config.yml`/`package.json`/`Makefile`)
**Result:** ✅ PASSED — all three exit 0. Plus the task harness, 64/64.

Coverage detail:

- `tests/lint.sh` — shellcheck + shfmt + markdownlint, all ok. Note this glob
  is `find . -maxdepth 2 -name '*.sh'`, so **neither `dwm-lock` nor any other
  `config/dwm/bin/*` script is in it** — both were shellchecked and shfmt'd by
  hand instead.
- `tests/pkglist.sh` — format, duplicates, core/extra overlap all ok. No
  package list changed here; `xss-lock` and `xset` were already declared.
- `tests/build.sh` — all five suckless programs build with no new warnings,
  confirming this needs no rebuild (`config.def.h` untouched).
- **Task harness, 64 assertions / 22 scenarios** against faked `xset`,
  `xss-lock`, `slock`, `loginctl` and `pgrep` on a `PATH` containing only the
  fake dir plus a symlinked real `bash`. Proven non-vacuous by two mutants: a
  wrong `LOCK_SECS` (caught, 3 failures) and a disabled logind route (caught,
  4 failures).
- **Four sandboxed `install_session_autostart` runs** with all four XDG vars
  redirected: fresh write (0755, line present), re-run (all four daemons
  reported ok), pre-existing `autostart.sh` (md5 identical afterwards — rule 6
  holds, and the paste line prints unexpanded), and `--dry-run` (zero files).
- `sxhkdrc` parsed by real sxhkd 0.6.3, clean; negative control `super + lll`
  produces `Unknown keysym name: 'lll'`, so silence is meaningful.

**Not covered:** `xss-lock`, `xset` and `slock` are all absent from this
Arch/Wayland host, so no assertion here observes an actual lock, an actual
DPMS transition, or an actual `XGrabKey` on `super + l`.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean on the first round — no issues raised, so nothing needed
resolving. The reviewer specifically confirmed the degradation paths, the
`exec` placement in both modes, the single-quoted heredoc (nothing expands at
install time, so the `${XDG_CONFIG_HOME:-$HOME/.config}` line reaches
`autostart.sh` literally), and that `super + l` sits entirely in sxhkd's Mod4
space with no collision against dwm's `keys[]` (MODKEY is `Mod1Mask`/Alt). It
also acknowledged the two disclosures rather than treating them as findings:
the fake-binary-only coverage, and the pre-existing `procps-ng`/`pgrep` gap.
