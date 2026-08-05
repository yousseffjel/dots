# MASTER_PLAN — dots

Strategic roadmap. One task per slot; multiple `## Active` entries allowed
when slots run concurrently. See `.claude/tasks/scope-a-theming-engine.md`
for the full Epic breakdown of the active item below.

---

## Active

### Epic: dark-mode-only theming engine (wallbash-for-X11)

HyDE-wallbash-inspired theming engine for the Fedora+dwm+X11+suckless
stack. Wallpaper -> ImageMagick color extraction -> dcol palette ->
template engine -> live targets (dwm/st/dmenu/slock/dwmblocks/dunst/
picom/gtk) -> atomic reload. Dark mode only, no light/mode-switching.

Scope file: `.claude/tasks/scope-a-theming-engine.md`
Status: decomposed, pending user approval to start Sub-task 1.

---

## Queue

*(nothing queued beyond the active Epic's sub-tasks — see scope file)*

---

## Recently Closed

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
