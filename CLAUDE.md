# dots — Project Context

Personal dotfiles + desktop bootstrap repo. Ships a suckless-based dwm/X11
desktop (dwm, st, dmenu, dwmblocks, slock — all vendored and patched from
upstream source) plus zsh/tmux shell config. **Fedora only** — one installer
(`scripts/install-fedora.sh`) installs the full desktop on either a fresh
Fedora Server or Fedora Workstation box, since it installs Xorg itself and
assumes no GUI is pre-installed. No package manager, framework, or build
system beyond `make` for the suckless C programs and plain bash for
orchestration.

`ROADMAP.md` is a comparison/aspiration doc (this repo vs. HyDE-Project's
Arch+Hyprland+Wayland setup) — see **Roadmap status** below for what it gets
right vs. what's already stale.

---

## Tech stack

- **Shell**: bash (`scripts/*.sh`, `set -euo pipefail`, all re-runnable/idempotent), zsh (user shell config in `config/zsh/`)
- **C**: vendored suckless sources (dwm, st, dmenu, dwmblocks, slock), built with `make`
- **Config**: tmux (`config/tmux/`), zsh (`config/zsh/`), dwm runtime scripts (`config/dwm/bin/`) — deployed via symlinks, not copies
- **No CI, no linter config, no test suite.** Verification is manual: `bash -n` on edited scripts, live package-manager checks (`dnf`/packages.fedoraproject.org lookups) when available, `make` build success for suckless programs.
- **Package declarations**: `packages/*.lst` — plain-text, one package per line, `#` comments, no parser dependency beyond `sed`/`tr`/`grep` (already used everywhere else in `scripts/`).

---

## Project map

```
dots/
├── config/
│   ├── zsh/            # zsh config: .zshrc, .zshenv, conf.d/, functions/, completions/
│   ├── tmux/            # tmux.conf, conf.d/, bin/, workflows/
│   └── dwm/bin/         # dmenu-driven scripts: dwm-powermenu, dwm-clipmenu (on $PATH via 20-path.zsh)
├── scripts/
│   ├── install-fedora.sh       # THE installer: thin orchestrator dispatching to the 4 stages below (+ --skip-suckless, --dry-run, --only-<stage>)
│   ├── install-pre.sh          # stage: sanity checks (dnf present, sudo available)
│   ├── install-pkg.sh          # stage: dnf packages (packages/*.lst) + clipmenu COPR + fd shim
│   ├── install-restore.sh      # stage: ZDOTDIR + symlinks.sh + zinit/TPM bootstrap clones
│   ├── install-services.sh     # stage: chsh to zsh + enable ly.service
│   ├── install-suckless.sh     # standalone builder: dwm/st/dmenu/dwmblocks/slock + autostart hook (called by the install stage unless --skip-suckless)
│   └── symlinks.sh             # symlinks config/zsh, config/tmux and config/dwm into ~/.config, backs up conflicts
├── packages/
│   ├── core.lst         # required dnf packages — install-fedora.sh hard-fails if any is missing
│   └── extra.lst        # best-effort dnf packages — skipped with a warning if missing/renamed
├── suckless/
│   ├── dwm/, st/, dmenu/, dwmblocks/, slock/
│   └── */patches/      # vendored .diff files per program, applied at build time
├── HyDE/                # untracked local clone of HyDE-Project/HyDE — reference only, not part of this repo
├── ROADMAP.md           # comparison doc vs. HyDE; see Roadmap status below
└── .claude/
    ├── changes/         # dated change logs (session-protocol.md governs this)
    └── state/
```

**Entry points**: `scripts/install-fedora.sh` is the single supported
installer — run it on a fresh Fedora Server or Fedora Workstation box to get
the full desktop (zsh/tmux + X11 + dwm/st/dmenu/dwmblocks/slock + ly). It's a
thin orchestrator over four idempotent, independently-runnable stages (pre ->
install -> restore -> services — `scripts/install-{pre,pkg,restore,services}.sh`);
`--only-<stage>` runs a single stage, `--dry-run` threads through every
stage without mutating anything. `scripts/install-suckless.sh` (re)builds
just the suckless programs standalone (also `--dry-run`-aware); `scripts/symlinks.sh`
(re)links shell config without touching packages (also `--dry-run`-aware).

---

## Roadmap status

`ROADMAP.md` was written by diffing this repo against HyDE-Project/HyDE and
is **partly stale** — treat it as a backlog of ideas, not a source of truth
for current state.

**Already done, ahead of what ROADMAP.md assumes:**
- A single Fedora installer (`scripts/install-fedora.sh`) covers both Fedora Server and Fedora Workstation targets — ROADMAP.md's §9 priority list treats "package lists + dnf installer" as not-yet-started; it already exists. **Scope note:** this repo previously also shipped `install-arch.sh`, `install.sh` (Debian/Ubuntu), `install-macos.sh`, and a separate `install-fedora-server.sh` — all four were dropped in favor of one Fedora-only installer (see `.claude/changes/` for the dated log). ROADMAP.md's Arch-comparison framing and any lingering references to those scripts elsewhere in this file predate that decision.
- dwm, st, dmenu, dwmblocks, and slock are all vendored *and* patched (pertag, statuscmd, systray, restartsig, actualfullscreen, hide_vacant_tags, dragmfact, scratchpads, status2d for dwm; border/center/fuzzymatch/lineheight/mouse/numbers/caseinsensitive for dmenu) — ROADMAP §2.5 lists this as a "to do" with only a subset of patches recommended.
- `install-suckless.sh` is the rebuild/build entry point already, doing the job ROADMAP §6 assigns to a not-yet-written `rebuild.sh`.
- Idempotent, re-runnable installers with colored logging and backup-on-conflict symlinking already exist — ROADMAP §2.1/§2.3 describe this as future infrastructure to add.
- Launcher, powermenu, and clipboard manager are done via dmenu (not rofi) — `Mod+p` (`dmenu_run`), `Super+Shift+x` (`config/dwm/bin/dwm-powermenu`), `Super+v` (`config/dwm/bin/dwm-clipmenu`, a thin wrapper around `clipmenu`/`clipnotify`). ROADMAP.md's comparison table and package list have been updated to match — dmenu was chosen over rofi to keep a single menu tool. clipmenu is COPR-only (`skidnik/clipmenu`); `install-fedora.sh` auto-enables that COPR as a deliberate, explicitly-approved exception to the "COPR is opt-in" default in rule 4 below, since the feature backs a core keybind.

**Still genuinely pending (ROADMAP is accurate here):**
- No compositor, notification daemon, wallpaper tool, screenshot tool, or lock/idle wiring yet (picom, dunst, feh, maim, xss-lock — ROADMAP §3).
- No theming engine / pywal-wallust integration, no `.Xresources`, no `themes/` directory.
- No `KEYBINDINGS.md`, no uninstaller, no `VERSION`/migrations.
- README.md is still a 7-byte stub.
- `install-fedora.sh` has not been run end-to-end on real hardware (per `.claude/changes/2026-08-04-fedora-arch-install-scripts-verify-fix.md`, written when an Arch installer still existed alongside it) — package names are verified against upstream repos, not live-tested.

When picking up ROADMAP.md work, re-check the relevant section against the
actual repo state first — don't assume an item is undone just because it's
listed there.

---

## Project-specific rules

These are conventions already established across `scripts/*.sh` — follow
them for any new or edited installer/build script rather than inventing a
new pattern.

1. **Every script is idempotent and re-runnable.** `set -euo pipefail` at the top; re-running after a partial or full success must be a safe no-op (or converge to the same state), never error out or duplicate work.
2. **Colored logging helpers, not raw `echo`.** Each script defines its own `red()`/`green()`/`yellow()`/`blue()` (`printf '\033[3xm%s\033[0m\n'`) — red for hard errors, green for confirmed/success/already-ok, yellow for warnings/manual-follow-up, blue for informational. Reuse this pattern verbatim in new scripts rather than introducing a different color scheme or a shared sourced file.
3. **`SCRIPT_DIR`/`DOTS_DIR` resolution pattern.** Every script computes its own location and the repo root the same way: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then `DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"`. Never hardcode paths.
4. **COPR-only packages are dropped from best-effort install loops, not silently attempted.** If a package isn't in Fedora's official repos (e.g. `lazygit`, `bibata-cursor-themes`), remove it from `packages/extra.lst`, add a header-comment note with the exact enable command (`dnf copr enable ...`), and print a closing yellow reminder. Enabling a third-party repo automatically is a separate trust decision, always left to the user — don't bootstrap COPR helpers from an installer script by default. **Exception:** `install-fedora.sh` auto-enables `skidnik/clipmenu` (clipmenu + clipnotify, dwm-clipmenu's backend) — the user explicitly authorized this one, in-session, rather than the default deferral. Treat any further auto-enable the same way: only after an explicit ask, never by default.
5. **Suckless patches are vendored as `.diff` files under `suckless/<program>/patches/`**, named `<patch>-<version-or-date>-<hash>.diff`, applied at build time by `install-suckless.sh`. Don't hand-edit the vendored `.c`/`.h` sources directly for something a patch already covers — add or update the `.diff` instead so the change survives a re-vendor.
6. **`install-suckless.sh` never overwrites user customizations** — `autostart.sh` and `.xinitrc` are treated as user-owned once they exist; preserve that guarantee in any change to the build/install flow.
7. **`symlinks.sh` links directories, not individual files**, and backs up pre-existing conflicting paths to `~/.dotfiles-backup/<timestamp>/` before linking — keep new config categories (e.g. a future `config/nvim/`) consistent with this backup-then-link behavior rather than a blind overwrite.
8. **Verification is manual.** When editing package names in `packages/*.lst`, check them against packages.fedoraproject.org — don't assume a package name is correct just because it looks plausible. Record verification method in the change log (per `session-protocol.md`).
9. **`HyDE/` is a local, untracked reference clone** (comparison source for `ROADMAP.md`) — it is not part of this project, must never be edited, symlinked into, or referenced by any script, and should not be assumed present on another machine.
10. **Package names live in `packages/*.lst`, never as inline arrays in installer scripts.** `packages/core.lst` is required (installer hard-fails on any missing package — reserve this for things later steps unconditionally depend on, like `git`/`zsh` for the bootstrap clones or `make`/`gcc`/`patch`/`pkgconf-pkg-config` for the suckless build); `packages/extra.lst` is best-effort (skipped with a yellow warning, never aborts the run). Both are one-package-per-line, `#`-commented, parsed with `sed`/`tr`/`grep` — no new dependency. Keep category comments (`# core system & display server`, etc.) as section dividers when adding packages, matching the existing grouping.
