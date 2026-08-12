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
- **CI and linters exist** (added 2026-08-05): `.github/workflows/ci.yml` runs lint / build-suckless / install-dry-run / tests jobs on a `fedora:latest` + **oldest-supported** matrix (`fedora:43` as of 2026-08-12 — the pin tracks the oldest supported release and must be bumped, not deleted, when that goes EOL; it sat at the long-dead `fedora:41` until then), backed by `.shellcheckrc`, `.markdownlint.yaml`, `.pre-commit-config.yaml` and `TESTING.md`. `tests/` holds `lint.sh`, `build.sh`, `pkglist.sh`, `picom-lockstep.sh`, `starship-template.sh`, `fastfetch-template.sh`, `autostart-daemons.sh`, `desktop-consequences.sh`, `tmux-tpm-lockstep.sh`, `manifest-has-path.sh`, `dwm-colorpicker.sh`, `dwm-display.sh` and `theme-identity.sh`. **Every test script is executed by CI** (2026-08-10): the `tests` job runs everything that needs only bash + coreutils, and the two it skips are *invoked* by the job that has their environment — `lint` runs `tests/lint.sh --strict` after installing the three linters, `build-suckless` runs `tests/build.sh` inside the Fedora container. Neither job restates those checks inline any more, so the scripts cannot rot unnoticed and the two copies cannot drift. `--strict` exists for exactly that wiring: `tests/lint.sh` skips a missing linter by default (useful locally), which in CI would mean a green job that checked nothing.
- **Beyond CI, verification is still manual and hands-on**: `bash -n`/`shellcheck` on edited scripts, package names checked against packages.fedoraproject.org (there is no `dnf` on the dev host — it is Arch), and sandboxed `$HOME` runs for anything touching the installer. Nothing has been run end-to-end on a real Fedora box.
- **Package declarations**: `packages/*.lst` — plain-text, one package per line, `#` comments, no parser dependency beyond `sed`/`tr`/`grep` (already used everywhere else in `scripts/`).

---

## Project map

```
dots/
├── config/
│   ├── zsh/             # zsh config: .zshrc, .zshenv, conf.d/, functions/, completions/
│   ├── tmux/            # tmux.conf, conf.d/, bin/, workflows/
│   ├── dwm/bin/         # dmenu-driven scripts: dwm-powermenu, dwm-clipmenu, dwm-wallpaper, dwm-theme, dwm-screenshot, dwm-lock, dwm-brightness, dwm-colorpicker, dwm-display
│   │                    # (on $PATH via config/zsh/.zshenv — NOT conf.d, which is interactive-only; dwm's autostart needs it)
│   ├── sxhkd/           # sxhkdrc — media/volume/brightness/screenshot/lock/theme keys (dwm keeps window management)
│   ├── alacritty/       # main terminal; alacritty.toml imports the engine's cached palette
│   ├── starship/        # starship.toml — prompt; themed via a spliced [palettes.dots] table
│   ├── thunar/, xfce4/  # thunarrc + uca.xml, helpers.rc — COPIED, never symlinked (the apps rewrite them)
│   ├── applications/    # dots-nvim.desktop
│   ├── mimeapps.list    # xdg default/added associations — COPIED (GIO rewrites it)
│   ├── dunst/, picom/   # base configs — COPIED by the installer, never symlinked (theming engine rewrites them)
│   └── theme/templates/ # .dcol templates: always/ (every wallpaper change), theme/ (theme switch only)
│                        # NOTE: there is deliberately no config/fastfetch/ or config/gtk-3.0/ —
│                        # those two configs are written ONLY by their templates (see docs/THEMING.md)
├── scripts/
│   ├── install-fedora.sh       # THE installer: thin orchestrator dispatching to the 4 stages below (+ --skip-suckless, --dry-run, --only-<stage>)
│   ├── install-pre.sh          # stage: sanity checks (dnf present, sudo available)
│   ├── install-pkg.sh          # stage: dnf packages (packages/*.lst) + clipmenu COPR + fd shim
│   ├── install-restore.sh      # stage: ZDOTDIR + symlinks.sh + theme deploy + app configs + zinit/TPM bootstrap clones
│   ├── install-restore-theme.sh # sourced by install-restore.sh: theme base-config deploy + manifest + backup
│   ├── install-restore-theme-identity.sh # the identity writers: render a theme.conf into settings.ini + xsettingsd.conf
│   │                                     # sourced by BOTH install-restore-theme.sh and scripts/theme/theme-apply.sh
│   ├── install-restore-apps.sh  # sourced by install-restore.sh: thunar/xfce4/mimeapps deploy + guarded xfconf pass
│   ├── install-services.sh     # stage: chsh to zsh + enable ly.service
│   ├── install-suckless.sh     # standalone builder: dwm/st/dmenu/dwmblocks/slock (called by the install stage unless --skip-suckless)
│   ├── install-session.sh      # sourced by install-suckless.sh: autostart.sh hook + ~/.xinitrc (both user-owned once they exist)
│   ├── install-session-template.sh # sourced by install-session.sh: the autostart.sh BODY (display / daemons / services parts)
│   ├── install-session-report.sh # sourced by install-session.sh: what to tell someone who already HAS an autostart.sh
│   ├── symlinks.sh             # symlinks the safe config/ dirs into ~/.config, backs up conflicts (--restore [timestamp] to undo)
│   ├── uninstall.sh            # + uninstall_steps.sh, uninstall-apps.sh — manifest-driven removal
│   ├── version.sh, migrate.sh  # + global_fn.sh, migrations/ — versioning and migration framework
│   └── theme/                  # theming engine: colorgen.sh, apply-templates.sh, reload.sh, wallpaper.sh, theme-apply.sh
├── packages/            # four tiers; tests/pkglist.sh globs them, never names them
│   ├── core.lst         # hard-fail — the installer's own next step breaks (git, zsh)
│   ├── build.lst        # suckless build deps — read by install-suckless.sh ONLY, not install-pkg.sh
│   ├── desktop.lst      # never aborts, but each failure is repeated in a red closing summary;
│   │                    # the trailing '#' on each line IS that package's consequence text
│   └── extra.lst        # best-effort applications and conveniences
├── suckless/
│   ├── dwm/, st/, dmenu/, dwmblocks/, slock/
│   └── */patches/      # vendored .diff files per program + PATCHES.md, applied at build time
├── themes/              # static themes: dark, gruvbox, nord, tokyo-night + CREDITS.md
├── tests/               # lint.sh, build.sh, pkglist.sh, picom-lockstep.sh, starship-template.sh,
│                        # fastfetch-template.sh, autostart-daemons.sh, desktop-consequences.sh,
│                        # tmux-tpm-lockstep.sh, manifest-has-path.sh,
│                        # dwm-colorpicker.sh, dwm-display.sh, theme-identity.sh
├── .github/workflows/   # ci.yml — lint / build-suckless / install-dry-run / tests
├── docs/                # THEMING.md, THUNAR.md, UNINSTALL.md
├── KEYBINDINGS.md       # every dwm and sxhkd binding
├── HyDE/                # untracked local clone of HyDE-Project/HyDE — reference only, not part of this repo
├── ROADMAP.md           # comparison doc vs. HyDE; see Roadmap status below
└── .claude/
    ├── changes/         # dated change logs (session-protocol.md governs this)
    ├── tasks/           # MASTER_PLAN.md + scope files + per-task folders
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
- dwm, st, dmenu, dwmblocks, and slock are all vendored *and* patched — ROADMAP §2.5 lists this as a "to do" with only a subset of patches recommended. The roster is 13 diffs for dwm (actualfullscreen, autostart, dragmfact, **dynamicscratchpads**, hide_vacant_tags, pertag, restartsig, status2d, status2d-systray, statuscmd, statuscmd-status2d, systray, xresources), 8 for dmenu (border, caseinsensitive, center, fuzzymatch, lineheight, mousesupport, numbers, xresources), and one each for st (xresources-signal-reload), dwmblocks (statuscmd) and slock (xresources). Each program's `patches/PATCHES.md` is the authoritative per-patch record; `ls suckless/*/patches/*.diff` is the source of truth for the list itself. The `*-local.diff` ones were captured against this tree rather than fetched from suckless.org, because they could not apply cleanly on top of the others.
  - **`scratchpads` was replaced by `dynamicscratchpads` on 2026-08-07** and the two are mutually exclusive (both claim bit `LENGTH(tags)` of the tag bitmask). Scratchpads are now assigned dynamically from the focused window rather than pre-declared as commands.
- `install-suckless.sh` is the rebuild/build entry point already, doing the job ROADMAP §6 assigns to a not-yet-written `rebuild.sh`.
- Idempotent, re-runnable installers with colored logging and backup-on-conflict symlinking already exist — ROADMAP §2.1/§2.3 describe this as future infrastructure to add.
- Launcher, powermenu, and clipboard manager are done via dmenu (not rofi) — `Mod+p` (`dmenu_run`), `Super+Shift+x` (`config/dwm/bin/dwm-powermenu`), `Super+v` (`config/dwm/bin/dwm-clipmenu`, a thin wrapper around `clipmenu`/`clipnotify`). ROADMAP.md's comparison table and package list have been updated to match — dmenu was chosen over rofi to keep a single menu tool. clipmenu is COPR-only (`skidnik/clipmenu`); `install-fedora.sh` auto-enables that COPR as a deliberate, explicitly-approved exception to the "COPR is opt-in" default in rule 4 below, since the feature backs a core keybind.

**Also done, superseding earlier "pending" entries (roster Epic, 2026-08-06/07 — scope file `.claude/tasks/scope-b-app-roster-finalization.md`):**
- **Screenshot and lock/idle both landed** (ROADMAP §3 is stale on this): `maim` + `slop` behind a dmenu mode menu in `config/dwm/bin/dwm-screenshot`, and `xss-lock` + `xset` + slock behind `config/dwm/bin/dwm-lock`. Both bound in `config/sxhkd/sxhkdrc`.
- alacritty is the main terminal (st retained as the no-GPU fallback); thunar is finalized with archive/thumbnail/mime defaults; the status bar runs 10 blocks plus the systray; picom is performance-tuned; the prompt is starship and fastfetch is the fetch tool. Both of the last two are themed from the wallpaper.
- **README.md is no longer a stub** — it carries the CI badge and the pre-commit setup.

**Roster gap-fill Epic closed 2026-08-12** (scope file
`.claude/tasks/scope-c-roster-gap-fill.md` — locked decisions live there):
xsettingsd, udiskie, autorandr, `dwm-colorpicker` (`Super+c`) and `dwm-display`
(`Super+d`). **ROADMAP §3's status column was reconciled at the same time and
§9 is entirely done** — treat `MASTER_PLAN.md` as the queue, not ROADMAP.
Two §3 rows remain open *by decision*, not omission: a blue-light filter
(undecided) and `xdg-desktop-portal-gtk` (deferred — only pays off with
Flatpak). **`xcolor` is not a Fedora package** — §3 named it for years; only
`texlive-xcolor`, a LaTeX package, exists. The colour picker is a script.

**Still genuinely pending (ROADMAP is accurate here):**
- No `.Xresources` **file** in the repo — deliberately: the theming engine generates `~/.cache/dots/theme/xresources` and `xrdb -merge`s it, so a static checked-in one would be immediately overwritten.
- `install-fedora.sh` has not been run end-to-end on real hardware (per `.claude/changes/2026-08-04-fedora-arch-install-scripts-verify-fix.md`, written when an Arch installer still existed alongside it) — package names are verified against upstream repos, not live-tested. **Nothing in the roster Epic changes this**: every sub-task was verified in sandboxed `$HOME` trees and against local binaries, never on a Fedora box. Treat "the installer works" as unproven.
- ~~The `core.lst` vs `extra.lst` split has never been reviewed as a whole.~~ **Done 2026-08-08** — reviewed as one pass and replaced with four tiers (see rule 10). The packages that back keybinds now sit in `desktop.lst`, whose failures are repeated in a red closing summary with what each one costs, so a failed install can no longer leave keys silently dead. Six packages that were declared nowhere are now declared: `libXext-devel`, `libXrandr-devel`, `libxcrypt-devel` and `ncurses` (they lived only in an inline array in `install-suckless.sh`), plus `procps-ng` and `desktop-file-utils`.

**Theming engine (added 2026-08-05, 7 sub-tasks — see `docs/THEMING.md`):**
- Dark-mode-only wallbash-style engine: wallpaper -> ImageMagick colour extraction (`scripts/theme/colorgen.sh`) -> `.dcol` palette -> template engine (`scripts/theme/apply-templates.sh`) -> live targets -> ordered reload (`scripts/theme/reload.sh`).
- dwm, st, dmenu and slock all read colours from the X resource database at runtime (xresources patches — see each tool's `patches/PATCHES.md`).
- User commands: `scripts/theme/wallpaper.sh` and `scripts/theme/theme-apply.sh`; the keybinds (`Super+w`, `Super+Shift+w`, `Super+Ctrl+w`) live in `config/sxhkd/sxhkdrc`, needing no dwm rebuild but depending on sxhkd being installed (it is in `desktop.lst`, so a failed install is reported loudly rather than silently) and running. They moved out of `config.def.h` in roster sub-task 4 and must not be re-added there — dwm and sxhkd both `XGrabKey`, and a doubly-bound key silently dies.
- **Four shipped static themes** — `dark` (Catppuccin Mocha), `gruvbox`, `nord`, `tokyo-night`. `config/theme/templates/` holds the `.dcol` templates. Every `colors.dcol` is **generated** by `colorgen.sh` from a four-block seed image, never hand-written, and each file's header records its seed hex so it can be regenerated; hand-written hex is how you get a palette missing a key some template references. **A theme switch applies the theme's identity too** (GTK theme name, icons, cursor, font) via the writers in `install-restore-theme-identity.sh` — `theme.conf` was report-only until 2026-08-12. Those writers never touch a `settings.ini`/`xsettingsd.conf` the manifest does not claim as ours, and only a *switch* (not an installer re-run) replaces one it does. All four `theme.conf` files currently carry identical values because the repo declares exactly one dark GTK theme; that is a packaging limit, not a design one. `tests/theme-identity.sh` guards the whole path.
- **`config/dunst` and `config/picom` must never be added to `symlinks.sh`** — the engine rewrites those whole files on every wallpaper change, and a symlink would make it write into this repo. The installer copies them instead.
- **Templates as of sub-task 9** (`always/`): `xresources`, `dunst`, `picom`, `gtk`, `statusbar`, `alacritty`, `starship`, `fastfetch`, `vim`. `cava.dcol` was **deleted** — it themed a program the installer never installs. Adding a template means reading `config/theme/templates/always/README.md` first: it documents the three target styles and, more importantly, which one is safe for a config that `symlinks.sh` links.
- **`gtk.css` and `fastfetch/config.jsonc` have no static copy under `config/` at all** — the `.dcol` is the sole authored version. That avoids the two-files-in-lockstep hazard `picom` has (where `config/picom/picom.conf` and `picom.dcol` must be hand-edited together or the first wallpaper change reverts the tuning), at the cost of two obligations on `install-restore-theme.sh`: create the parent directory, or the engine's install-check skips the template forever; and claim the path in the manifest, or uninstall cannot remove it. **Do not add a `config/fastfetch/` directory** — it would reintroduce exactly the lockstep problem.
- **`xsettingsd.conf` is written by the installer, NOT by a template** — `theme_write_xsettingsd_conf` in `scripts/install-restore-theme-identity.sh`. It carries the GTK theme identity from the active theme's `theme.conf` (`themes/dark/` by default; a switch re-renders it from the selected theme) plus the Xft rendering keys (`Xft/Antialias`, `Xft/Hinting`, `Xft/HintStyle`, `Xft/RGBA`), which live nowhere else in this repo — `xresources.dcol` is colours only. None of it is palette-derived, so a `.dcol` would re-render an identical file on every wallpaper change. `Xft/DPI` is deliberately omitted: hardcoding `96*1024` would override X's autodetection and break HiDPI. It is still in `reload.sh`'s sweep (`pkill -HUP`) so an installer re-run or a `theme.conf` edit needs no logout. **xsettingsd has no CSS channel** — it plays no part in the wallpaper accent colours, which are `gtk.css` and reload on their own.
- **starship is themed by splicing, not by regenerating.** `config/starship/starship.toml` is the authored config and stays symlinked; `starship.dcol` renders only its `[palettes.dots]` table, and the post-command writes a combined copy to the cache that `conf.d/99-prompt.zsh` prefers while it is newer. The marker line `# ### dots-theme palette ###` in `starship.toml` is load-bearing — it is where the splice cuts, and the template refuses to touch a config that lacks it.

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

    **Adding an autostart entry is a three-place change**, and all three are enforced: the launch line in one of `session_autostart_display` / `_daemons` / `_services` (all three now in `install-session-template.sh`, split off from `install-session.sh` at the 250-line cap), a matching `session_report_daemon` call (`install-session-report.sh`) so existing installs — whose `autostart.sh` is user-owned and never rewritten — are told what to paste, and the name in `DAEMONS` in `tests/autostart-daemons.sh`. That test RUNS both sides rather than parsing them and has caught an unpaired entry unprompted more than once, so skipping any of the three fails the build rather than shipping a daemon nobody launches. The template is three parts purely for the 60-line function cap; the test calls only `session_autostart_template` and `session_autostart_report`, so splitting it again costs the test nothing. **Do not re-add an enumerated daemon list anywhere else** — the user-facing "wrote autostart.sh" message used to carry one and had already gone stale.
7. **`symlinks.sh` links directories, not individual files**, and backs up pre-existing conflicting paths to `~/.dotfiles-backup/<timestamp>/` before linking — keep new config categories (e.g. a future `config/nvim/`) consistent with this backup-then-link behavior rather than a blind overwrite. `symlinks.sh --restore [timestamp]` reverses a backup: no timestamp lists what's available under `~/.dotfiles-backup/`, a timestamp removes the matching symlink(s) and moves the backed-up originals back — it never touches a target that isn't currently one of its own symlinks (skips with a warning instead of overwriting unknown state).
8. **Verification is manual.** When editing package names in `packages/*.lst`, check them against packages.fedoraproject.org — don't assume a package name is correct just because it looks plausible. Record verification method in the change log (per `session-protocol.md`).
9. **`HyDE/` is a local, untracked reference clone** (comparison source for `ROADMAP.md`) — it is not part of this project, must never be edited, symlinked into, or referenced by any script, and should not be assumed present on another machine.
10. **Package names live in `packages/*.lst`, never as inline arrays in installer scripts.** Four tiers, each with a different failure mode — pick by asking *what breaks, and does it announce itself?*

    | List | Consumer | On failure |
    | ---- | -------- | ---------- |
    | `core.lst` | `install-pkg.sh` | **Aborts the run.** Only for things the installer's own next step needs unconditionally — `git` for the zinit/TPM clones, `zsh` for the chsh step. Keep it tiny: rule 8 means these names are hand-checked, never checked against a live `dnf`, so a rename here turns a degraded install into no install. |
    | `build.lst` | `install-suckless.sh` **only** | **Aborts the build stage.** The suckless toolchain and headers. `install-pkg.sh` deliberately does not read it — `install-fedora.sh` runs the build stage right after, without `--skip-deps`, so `--skip-suckless` needs no special handling anywhere. |
    | `desktop.lst` | `install-pkg.sh` | **Never aborts**, but every failure is repeated in a red closing summary. For packages whose absence is otherwise **silent**: a dead keybind, a daemon that never starts, a theming engine that cannot run. |
    | `extra.lst` | `install-pkg.sh` | **Never aborts.** Applications and conveniences; failures get one yellow line in the summary. |

    **The trailing `#` comment on a `desktop.lst` line is load-bearing** — it is that package's consequence text, and `load_consequences()` in `install-pkg-tiers.sh` reads it back out to build the summary. `read_pkg_list()` already strips trailing comments, so the install path is unaffected and the fact lives in one place. `tests/desktop-consequences.sh` fails the build if an entry lacks one, and does it by extracting the *shipped* parser rather than reimplementing it.

    **One documented exception:** `install_deps()` in `install-suckless.sh` keeps inline arrays for its `pacman` and `apt-get` branches. A `.lst` holds one distro's package names, and those two are different names for the same libraries; only the `dnf` branch reads `build.lst`. They are vestigial fallbacks from when this repo still shipped `install-arch.sh` and `install.sh`, kept because `install-suckless.sh` is documented as standalone-runnable. Don't add a third distro this way — extend the format instead, or drop them.

    All four are one-package-per-line, `#`-commented, parsed with `sed`/`tr`/`grep` — no new dependency. Keep category comments (`# core system & display server`, etc.) as section dividers. **Never name the lists in a consumer** — `tests/pkglist.sh` and `ci.yml` both glob `packages/*.lst`, so a fifth tier is covered for free; a named loop silently stops covering whatever is added next.
