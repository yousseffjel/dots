# first-boot-fixes
Date: 2026-10-05
Files: 19 | Lines: +524/-65 (17 modified + 2 new tests; excludes task folder and state)

## What changed
- **picom backend probe** (`scripts/install-session-template.sh`): new
  `session_autostart_compositor` part (the template is now four parts, for the
  60-line cap). Runs `timeout 5 glxinfo -B`; `--backend glx` only on
  `direct rendering: Yes` with a renderer that is not llvmpipe/softpipe/swrast,
  `--backend xrender` otherwise — including glxinfo or timeout missing.
  `picom.conf`/`picom.dcol` untouched (the CLI flag overrides them).
  `session_report_picom_probe` (`install-session-report.sh`) warns about an
  existing `autostart.sh` that starts picom without choosing a backend.
- **`glx-utils`** added to `packages/desktop.lst` with consequence text.
- **Theme at login** (`scripts/install-session.sh`): the `.xinitrc` body moved
  into `session_xinitrc_template`. Before `exec dwm`: with a cache, `xrdb
  -merge` it and run `~/.fehbg`; without one (every headless install), run
  `~/.local/bin/dots theme dark` under `timeout 120`. An existing `.xinitrc` gets
  `session_xinitrc_report` (prints the lines to paste) instead of a bare
  "left untouched". `install-restore-theme.sh`'s headless skip line now
  says the theme applies on first login, and is blue rather than yellow.
- **Login shell**: `install-services.sh` and `uninstall_steps.sh` use
  `"${SUDO[@]}" usermod -s <shell> <user>` instead of `chsh -s`, with stderr
  visible. `usermod` added to the symmetry test's sentinel list.
- **Tests**: new `tests/picom-backend-probe.sh` (9 backend cases + 3 report
  cases) and `tests/xinitrc-theme.sh` (5 theme cases + 2 report cases). Both
  RUN the generated file under `/bin/sh` with a PATH of fakes only.
- **Docs**: CLAUDE.md (first VM run recorded; rule 6 gains the xinitrc/picom
  paragraph and loses its enumerated part names), docs/THEMING.md (picom
  backend note + new "At login" section), TESTING.md (two new tests; the
  container's login-shell row now says it only proves the root path),
  docs/UNINSTALL.md, CHANGELOG.md Unreleased/Fixed, install-container.yml's
  "not covered" block, and `chsh` wording in core.lst/install-pkg.sh.

## Why
First end-to-end install on real Fedora: Fedora 44 Server, a libvirt VM with
a `Virtio 1.0 GPU` (no virgl), logged in through ly, which runs `~/.xinitrc`.
The user saw dwm's default colours and a bar stuck at `dwm-6.8`, and
Super+Shift+Enter appeared to do nothing. Diagnosis over SSH:
`autostart.sh` had run; dwmblocks, sxhkd, xsettingsd and lxpolkit were up;
the root window's `WM_NAME` held the full 10-block status; dwm was idle in
`poll_schedule_timeout`, not hung; and the "nothing" was a mapped Alacritty
window with invisible contents. `pkill -x picom` made everything appear at
once, so picom's glx backend had stopped repainting the screen. Separately,
`install-restore-theme.sh` skips theming without `$DISPLAY` (always true on
Server) and nothing themed at login. Also, `getent` showed `/bin/bash`:
non-root `chsh` needs a PAM password on a terminal, failed with stderr
suppressed, and printed only a yellow line. The container CI job passed it
for months because it runs as root.

## Assumptions
- **Theme restore in `~/.xinitrc`, not `autostart.sh`** (Type B; deviates
  from the first proposal, disclosed at /plan). `reload.sh` sends dwm `kill
  -HUP` → restartsig re-exec → `runautostart()` runs again on every start
  (`dwm.c` main) → a theme step in autostart.sh would loop. dwm reads
  xresources once at startup, so merging before `exec dwm` takes effect with
  no restart.
- **No glxinfo = xrender** (Type B): a frozen screen is far worse than a slower
  compositor, and the shipped config uses no glx-only effect (shadow off, no blur).
- **`glx-utils` package name**: verified on packages.fedoraproject.org
  (subpackage of mesa-demos, in f43/f44/f45/rawhide; provides glxinfo). Rule
  8: not checked against a live dnf, and the `/usr/bin/glxinfo` path is assumed.
- **Fake glxinfo format** follows mesa-demos' glxinfo.c, not a live capture:
  the dev host has no glxinfo.
- **First-login theming is unproven on the VM.** `dots theme dark` running
  before any WM exists (reload.sh skips dwm; it only restarts dwmblocks/dunst
  if they were already running) is reasoned from the code, not observed.
- User decisions (2026-10-05): picom = probe at login; all three bugs in one slot.

## Test coverage
- `tests/run-tests.sh`: 25/25 OK, 0 skipped. `tests/lint.sh`: shellcheck
  0.11.0, shfmt, markdownlint all clean.
- Mutation check on a scratch copy (never the worktree): 3 mutations to the
  picom probe (default glx, drop llvmpipe, drop direct-rendering check) and
  4 to the xinitrc (drop timeout, wrong cache path, drop fehbg, `exec dwm`
  before the theme step): all 7 caught, each for the intended assertion.
- Caught during /code: `report | grep -q` under pipefail returned 141 only
  under run-tests.sh (passed when run alone), so both new tests now use
  here-strings. A wrapped comment line beginning with "shellcheck 0.10.0"
  was parsed as a directive (SC1072/1073). Both are known traps from memory.
- Reviewer gate: READY. `git diff HEAD` was unchanged before and after the
  review.
- NOT covered: anything on the real VM after the fix.

## Follow-ups
- Re-test on the VM: remove `~/.local/share/dwm/autostart.sh` and
  `~/.xinitrc`, re-run `scripts/install-fedora.sh --only-install`, log in via
  ly. Check that the bar is themed, `pgrep -a picom` shows `--backend xrender`,
  and `getent passwd $USER` shows zsh (needs `--only-services` too).
- MASTER_PLAN queue item "Run install-fedora.sh end-to-end on real hardware":
  now partially done (VM, not bare metal). Update on main post-merge.
- Open: ship a default wallpaper? `themes/*/wallpapers/` holds only a README,
  so `~/.fehbg` stays absent until `dots wallpaper <file>`.
- Faint image visible behind windows on the VM: not investigated, likely
  framebuffer residue from before X; re-check once picom runs on xrender.
