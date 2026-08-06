# MASTER_PLAN — dots

Strategic roadmap. One task per slot; multiple `## Active` entries allowed
when slots run concurrently.

---

## Active

- **Epic: app / tool / package roster finalization.** 10 sub-tasks, one
  per slot. Scope file: `.claude/tasks/scope-b-app-roster-finalization.md`
  (locked decisions live there — do not re-litigate them).
  - [x] 1. zsh: purge HyDE leftovers, retarget at dwm/X11 (+ starship.toml, zoxide) — `97b41b9`
  - [x] 2. `packages/*.lst` final roster + starship adoption + Nerd Font — `1129cf9`
  - [ ] 3. alacritty as main terminal (st retained as fallback)
  - [ ] 4. sxhkd keybind split with dwm
  - [ ] 5. screenshot — maim + slop + dmenu mode menu
  - [ ] 6. lock / idle — xss-lock + xset + slock
  - [ ] 7. status bar blocks — Layout A, 10 blocks + tray (order locked)
  - [ ] 8. thunar finalization (archives, thumbnails, defaults, terminal)
  - [ ] 9. fastfetch + starship theming + cava removal + docs
  - [ ] 10. picom performance tuning (template + base config in lockstep)

  Order: 1 and 2 first (independent, unblock the rest); 3 before 8;
  4 before 5 and 6; 7 and 10 independent; 9 last.

---

## Queue

- **Bound `xresources.dcol`'s `xrdb -merge` post-command.** It is
  unbounded, unlike `reload.sh`'s, which wraps its `xrdb` in
  `timeout 10`. A hung X server hangs the whole template run.
- **`TPM_DIR` in `install-restore.sh` ignores `$XDG_DATA_HOME`,**
  hardcoding `$HOME/.local/share` while `ZINIT_HOME` right above it
  honours the variable.
- **Run `install-fedora.sh` end-to-end on real hardware.** Still never
  done; package names are verified against upstream repos, not live.
- **README.md is still a 7-byte stub.**

---

## Recently Closed

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
