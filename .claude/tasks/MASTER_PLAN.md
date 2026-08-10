# MASTER_PLAN — dots

Last Updated: 2026-08-08

Strategic roadmap. One task per slot; multiple `## Active` entries allowed
when slots run concurrently.

---

## Active

*(none — the roster Epic closed 2026-08-07; see Recently Closed)*

---

## Queue

- **`scripts/install-session.sh` is at exactly 250 lines, the cap.** Adding a
  seventh autostart daemon forces a *file* split, not just a function split —
  `polkit-autostart-tiers` already spent both available function splits
  (`session_report_daemon`, and `session_autostart_daemons`/`_services`). The
  natural seam is a `install-session-report.sh` sibling, matching how
  `install-restore.sh` sources `install-restore-theme.sh`. Do this *before*
  wiring the next daemon, not during.
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

- 2026-08-08 — **polkit autostart + keybound apps re-tiered** — `51a728d`,
  `24f77fc`. Closed two queue items at once. The polkit agent is launched from
  `autostart.sh` by absolute path (its binary is not on `PATH`, so the
  `command -v` pattern the other five daemons use would have silently never
  fired). `thunar` and `firefox` moved to `desktop.lst` — a **DECISION
  REVERSAL** of `package-tiers`, decided on the criterion written in
  `desktop.lst` rather than the unwritten one I had applied. Adding a sixth
  daemon broke the 60-line cap twice, forcing two provably output-identical
  refactors, and `tests/autostart-daemons.sh` was rewritten to RUN both
  functions rather than parse them.

- 2026-08-08 — **package tiers** — `5a4e681`, `13b6902`. The `core.lst` vs
  `extra.lst` review, five sub-tasks deep. Answer was not a promotion list:
  the two-tier model could not express "serious but must not abort", so
  everything load-bearing sat in best-effort `extra.lst`. Now four tiers
  (`core` 2 / `build` 13 / `desktop` 26 / `extra` 61) plus a closing failure
  summary that names each casualty and what it costs. `core.lst` *shrank* to
  `git`+`zsh` — a hard-fail on a hand-checked name would turn a degraded
  install into none. Six previously-undeclared packages now declared, the
  rule 10 inline-array violation closed, and both `tests/pkglist.sh` and
  `ci.yml` now glob the lists so a fifth tier needs no code change.

- 2026-08-08 — **picom autostart** — `592abb3`. picom added to the
  `autostart.sh` template (first, before the other four daemons) plus a
  matching branch in `session_autostart_report()`; `tests/autostart-daemons.sh`
  now pairs the two daemon sets so the same drift cannot recur. Fixed a
  pre-existing 60-line-cap violation in `install_session_autostart()` in
  passing. **Existing installs still need the line pasted by hand** —
  `autostart.sh` is user-owned (CLAUDE.md rule 6), so the installer only
  reports it.

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
