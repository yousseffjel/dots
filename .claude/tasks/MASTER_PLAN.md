# MASTER_PLAN — dots

Last Updated: 2026-08-07

Strategic roadmap. One task per slot; multiple `## Active` entries allowed
when slots run concurrently.

---

## Active

*(none — the roster Epic closed 2026-08-07; see Recently Closed)*

---

## Queue

- **Nothing autostarts picom.** Found 2026-08-07 while reconciling ROADMAP §3
  in sub-task 9. picom is packaged, configured, themed *and* performance-tuned
  (sub-task 10), but it appears in no autostart path — not the `autostart.sh`
  template in `scripts/install-session.sh`, not `~/.xinitrc`, not sxhkd — and
  `scripts/theme/reload.sh` only signals it *if already running*. So sub-task
  10's tuning has never taken effect on a real session, and neither has the
  compositor. Fix is one guarded line in the `autostart.sh` heredoc, next to
  the existing dwmblocks/clipmenud/sxhkd ones. **Note `autostart.sh` is
  user-owned once it exists (CLAUDE.md rule 6)**, so existing installs need
  the line added by hand — the same caveat sub-tasks 4 and 6 shipped, and it
  needs a documented note, not just a template edit. `dunst` needs no such
  line (D-Bus activates it, which is also why `reload.sh` can just kill it).
- **Decide which roster packages are load-bearing enough for `core.lst`.**
  Raised and deferred by four separate sub-tasks now — `alacritty` (3),
  `sxhkd` (4), `maim`/`slop`/`xprop` (5), `procps-ng` (6) — each time into a
  change log the next sub-task never reads. `extra.lst` is best-effort, so a
  package that fails to install leaves keybinds silently dead: no sxhkd means
  every media/volume/theming/screenshot/lock key is inert, no `pgrep` means
  `dwm-lock --daemon` loses its duplicate-daemon guard. Needs one pass over
  the whole roster, not another follow-up line.
- **Make CI invoke `tests/build.sh` and `tests/lint.sh` instead of
  duplicating them.** Sub-task 10 added a `tests` job that runs `tests/*.sh`
  by glob, but it skips those two — the first needs the X11 toolchain, the
  second needs shellcheck/shfmt/markdownlint, and running them on a bare
  ubuntu-latest runner would make the job red. The `build-suckless` and
  `lint` jobs already provide exactly those environments, but they
  re-implement the same checks inline rather than calling the scripts. So
  both scripts could rot without CI noticing, and the inline copies can
  drift from them. Have those two jobs call the scripts.
- **Fix the `pipefail` SIGPIPE bug in `install-restore-theme.sh`.**
  `theme_is_ours` and `theme_backed_up` both pipe into `grep -qxF`; grep's
  early exit SIGPIPEs `cut`, and under `set -o pipefail` the pipeline
  returns 141 *even on a match*, so a file the installer deployed is
  misreported as one to leave alone. Demonstrated 5/5 on a 200k-row
  manifest during sub-task 8, which fixed the same bug in its own new
  code. `install-restore.sh:72` already carries a `|| true` and a
  five-line comment for the identical trap in a `comm | head`, so this is
  the third site. Low urgency — the theme manifest is a handful of rows,
  far from the scale that triggers it — but it is shipped code. Note
  `|| true` is not the fix; it maps 141 to 0, the opposite wrong answer.
- **Bound `xresources.dcol`'s `xrdb -merge` post-command.** It is
  unbounded, unlike `reload.sh`'s, which wraps its `xrdb` in
  `timeout 10`. A hung X server hangs the whole template run.
- **`TPM_DIR` in `install-restore.sh` ignores `$XDG_DATA_HOME`,**
  hardcoding `$HOME/.local/share` while `ZINIT_HOME` right above it
  honours the variable.
- **Run `install-fedora.sh` end-to-end on real hardware.** Still never
  done; package names are verified against upstream repos, not live. The
  whole roster Epic was verified in sandboxed `$HOME` trees and against
  local binaries on an **Arch** dev host — never on a Fedora box.

---

## Recently Closed

- 2026-08-07 — **Epic: app / tool / package roster finalization**, all 11
  sub-tasks merged. Scope file:
  `.claude/tasks/scope-b-app-roster-finalization.md` (locked decisions live
  there — do not re-litigate them).
  - [x] 1. zsh: purge HyDE leftovers, retarget at dwm/X11 (+ starship.toml, zoxide) — `97b41b9`
  - [x] 2. `packages/*.lst` final roster + starship adoption + Nerd Font — `1129cf9`
  - [x] 3. alacritty as main terminal (st retained as fallback) — `f5f148a`
  - [x] 4. sxhkd keybind split with dwm — `b8a17e0`
  - [x] 5. screenshot — maim + slop + dmenu mode menu — `b2dcb13`
  - [x] 6. lock / idle — xss-lock + xset + slock — `4ebf84b`
  - [x] 7. status bar blocks — Layout A, 10 blocks + tray (order locked) — `d2a2c57`
  - [x] 8. thunar finalization (archives, thumbnails, defaults, terminal) — `b11fd73`
  - [x] 9. fastfetch + starship theming + cava removal + docs — `d3fa7f1`
  - [x] 10. picom performance tuning (template + base config in lockstep) — `f4a44aa`
  - [x] 11. dynamic scratchpads — dwm patch swap — `9202bfb`

- 2026-08-06 — **Epic: dark-mode-only theming engine (wallbash-for-X11)**,
  all 7 sub-tasks merged. Wallpaper -> ImageMagick colour extraction ->
  dcol palette -> template engine -> live targets (dwm/st/dmenu/slock/
  dwmblocks/dunst/picom/gtk/vim/cava) -> atomic reload. Dark mode only.
  Scope file: `.claude/tasks/scope-a-theming-engine.md`.
  - [x] 1. xresources patches (dwm/st/dmenu/slock) — commit `1f43276`
  - [x] 2. colorgen.sh (ImageMagick dark-mode dcol extraction) — `b98dde8`
  - [x] 3. apply-templates.sh (template engine) — commit `1d57148`
  - [x] 4. templates + base dunstrc/picom.conf — commit `27b2e40`
  - [x] 5. reload.sh (atomic ordered reload) — commit `5e79ceb`
  - [x] 6. wallpaper.sh / theme-apply.sh + keybinds — commit `f85bb8a`
  - [x] 7. static dark theme + packaging + docs — commit `ff1ca5c`
- 2026-08-06 — vim + cava app templates (post-Epic follow-up) — `399c412`
- 2026-08-05 — uninstall/versioning/migrations subsystem (VERSION,
  scripts/version.sh, global_fn.sh, uninstall.sh, migrations framework)
- 2026-08-05 — CI tooling (shellcheck/shfmt/markdownlint, pre-commit,
  GitHub Actions, tests/)
- 2026-08-05 — post-push verification audit (3 parallel read-only audits,
  bugs found and fixed in version.sh/install-restore.sh/.shellcheckrc)

## Completed

*(see `.claude/changes/` dated logs for full history predating this file)*

## Deferred

*(none)*
