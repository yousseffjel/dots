# dots — Project Context

Personal dotfiles + desktop bootstrap repo. Ships a suckless-based dwm/X11
desktop (dwm, st, dmenu, dwmblocks, slock — all vendored and patched from
upstream source) plus zsh/tmux shell config. **Void Linux only** (glibc,
x86_64, runit) — one installer (`scripts/install-void.sh`) installs the full
desktop on a fresh **Void base install**, since it installs Xorg itself and
assumes no GUI is pre-installed. No package manager, framework, or build
system beyond `make` for the suckless C programs and plain bash for
orchestration.

**Void port merged 2026-10-15** (branch `void` fast-forwarded into `main`;
the last Fedora commit is `e89cd01`). The target moved from Fedora Server to
Void Linux by user decision, a DECISION REVERSAL of "Fedora only" and of the
2026-10-14 "Server is the one supported target".
`.claude/tasks/scope-i-void-port.md` holds the locked decisions: ly built from
source with a sha256-pinned zig, elogind, and vendored Cascadia Code NF.
Fedora still appears below as history (why something was built the way it
was, and what was verified when); every statement of current behaviour was
reconciled with the Void scripts on 2026-10-19. Where the two still
disagree, the scripts are the authority. Package names are checked against Void's official repodata
(`repo-default.voidlinux.org/current`, rule 8). **Scope J (2026-10-16)** added
a second, earlier entry point: `scripts/install-live.sh` installs Void itself
from the live ISO, then this desktop (`docs/LIVE-INSTALL.md`).

`ROADMAP.md` is a comparison/aspiration doc (this repo vs. HyDE-Project's
Arch+Hyprland+Wayland setup) — see **Roadmap status** below for what it gets
right vs. what's already stale.

---

## Tech stack

- **Shell**: bash (`scripts/*.sh`, `set -euo pipefail`, all re-runnable/idempotent), zsh (user shell config in `config/zsh/`)
- **C**: vendored suckless sources (dwm, st, dmenu, dwmblocks, slock), built with `make`. nsxiv, the image viewer, was vendored here too until 2026-10-19; it is now Void's package (`extra.lst`)
- **Config**: tmux (`config/tmux/`), zsh (`config/zsh/`), dwm runtime scripts (`config/dwm/bin/`) — deployed via symlinks, not copies
- **CI and linters exist** (added 2026-08-05): `.github/workflows/ci.yml` runs lint / tests / build-suckless / package-names jobs, and `.github/workflows/install-container.yml` runs the one job that actually executes the installer (split out 2026-08-13; it carries a `paths:` filter so a docs-only push skips it). The container jobs run in **`ghcr.io/void-linux/void-glibc-full:latest`**, one leg each (scope I, I-9, 2026-10-15): Void is rolling, so the Fedora-era `fedora:latest` + oldest-supported matrix has no equivalent. The image is bare (no bash, no git), so each job starts with an `sh` step that syncs, updates xbps, upgrades, and adds both. `package-names` checks every list name against the live index, catching the drift `tests/void-pkgnames.sh`'s committed snapshot cannot. Backed by `.shellcheckrc`, `.markdownlint.yaml`, `.pre-commit-config.yaml` and `TESTING.md`. **`ls tests/*.sh` is the source of truth for what the suite contains** — this file used to restate all thirteen names and went stale the moment a fourteenth was added, which is the same lesson rule 6 records for daemons and rule 10 for package lists. **Every test script is executed by CI** (2026-08-10): the `tests` job runs everything that needs only bash + coreutils, and the two it skips are *invoked* by the job that has their environment — `lint` runs `tests/lint.sh --strict` after installing the three linters, `build-suckless` runs `tests/build.sh` inside the Void container. Neither job restates those checks inline any more, so the scripts cannot rot unnoticed and the two copies cannot drift. `--strict` exists for exactly that wiring: `tests/lint.sh` skips a missing linter by default (useful locally), which in CI would mean a green job that checked nothing. **All three linters are version-pinned as of 2026-08-14** — shellcheck used to be whatever the runner image happened to ship, and because 0.10.0 renamed the unreachable-function-body finding (SC2317 → SC2329), a `# shellcheck disable=` directive that satisfied the dev host's 0.11.0 turned the job red. `ci.yml` now downloads a checksum-verified shellcheck matching the `shellcheck-py` rev in `.pre-commit-config.yaml`, and `tests/shellcheck-pin.sh` fails the build when those two pins drift. **Since 2026-09-28 that test is `tests/linter-pins.sh` and covers shfmt and markdownlint too**, because `.github/dependabot.yml` now bumps the pre-commit revs and cannot touch ci.yml's env vars — its PR for a linter hook stays red until the ci.yml twin moves in the same branch.
- **Beyond CI, verification is still manual and hands-on**: `bash -n`/`shellcheck` on edited scripts, package names checked against Void's repo index (rule 8; there is no `xbps` on the dev host — it is Arch), and sandboxed `$HOME` runs for anything touching the installer. The `install-container` workflow (2026-08-13) runs the installer end-to-end in a Void container (Fedora until the port) and asserts on the result, which is the only automated check of the *whole* flow — but a container is not a machine: a runit service link is not a running service, and every graphical path is outside what it can prove (the login-shell step too, but only as root — see TESTING.md), and the job says so in its own output. **Nothing has been run end-to-end on bare metal.** On Fedora, the **first end-to-end run was 2026-10-05, a Fedora 44 Server VM** (libvirt, virtio GPU without 3D acceleration, login via ly) — still not bare metal. It found three bugs no container or sandbox could: picom's glx backend freezing the screen, a headless install never theming the desktop, and `chsh` failing silently for a non-root user. See `.claude/changes/` for the dated log. **The first Void run was 2026-10-15** (a Void glibc VM, QXL, login via ly; `dots doctor` all passed). It found one bug, the VOL block drawn before WirePlumber restored the volume, fixed by `dwm-audiowatch`. **Since 2026-10-19 the live-ISO path has a VM matrix too**: {UEFI, BIOS} × {plain, LUKS} from the Void live ISO to the ly login (`docs/LIVE-INSTALL.md`), which found ly's first-login bug.
- **Package declarations**: `packages/*.lst` — plain-text, one package per line, `#` comments, no parser dependency beyond `sed`/`tr`/`grep` (already used everywhere else in `scripts/`).

---

## Project map

```
dots/
├── config/
│   ├── zsh/             # zsh config: .zshrc, .zshenv, conf.d/, completions/
│   │                    # (completions/ holds _dots; fpath is extended in conf.d/30-zinit.zsh
│   │                    #  BEFORE compinit runs there — an addition after it is a no-op.
│   │                    #  There is no functions/ dir; this map claimed one for months.)
│   ├── tmux/            # tmux.conf, conf.d/, bin/, workflows/
│   ├── dwm/bin/         # dmenu-driven scripts: dwm-apps (the Super+space launcher), dwm-powermenu, dwm-clipmenu, dwm-wallpaper, dwm-theme, dwm-screenshot, dwm-lock, dwm-brightness, dwm-colorpicker, dwm-display, dwm-osd, dwm-keys, dwm-emoji, dwm-record, dwm-nightlight, dwm-power, dwm-picom (picom backend), dwm-notify (notification centre + focus mode), dwm-audiowatch (redraws VOL/MIC on PipeWire events), dwm-shotkey (Super+a read WITHOUT a key grab, so a browser dropdown survives the screenshot)
│   │                    # (on $PATH via config/zsh/.zshenv — NOT conf.d, which is interactive-only; dwm's autostart needs it)
│   │                    # dwm-lib-*.sh are SOURCED (644, so dmenu never lists them): -xdg (where screenshot,
│   │                    #  record and wallpaper.sh save/read), -screenshot (dwm-screenshot's capture half),
│   │                    #  -monitor (the monitor under the pointer, for screenshot and record)
│   ├── sxhkd/           # sxhkdrc — media/volume/brightness/screenshot/lock/theme keys (dwm keeps window management)
│   ├── alacritty/       # main terminal; alacritty.toml imports the engine's cached palette
│   ├── starship/        # starship.toml — prompt; themed via a spliced [palettes.dots] table
│   ├── thunar/, xfce4/  # thunarrc + uca.xml, helpers.rc — COPIED, never symlinked (the apps rewrite them)
│   ├── applications/    # dots-nvim.desktop, dots-st.desktop (st has no .desktop of its own; dwm-apps lists only those)
│   ├── mimeapps.list    # xdg default/added associations — COPIED (GIO rewrites it); docs/THUNAR.md has the table.
│   │                    # A claimed copy identical to a committed version is replaced on re-run (deploy_app_file)
│   ├── mpv/             # mpv.conf — gpu-next HDR tone-mapping + hwdec; symlinked (mpv writes state to XDG_STATE_HOME)
│   ├── autorandr/       # postswitch.d/ wallpaper re-paint + brightness sync hooks — COPIED, never linked (`autorandr --save` writes profiles there)
│   ├── fontconfig/      # fonts.conf — Latin face first, Noto Arabic behind it; symlinked (docs/FONTS.md)
│   ├── xorg/            # 40-dots-touchpad.conf — COPIED by drivers-laptop.sh to /etc/X11/xorg.conf.d on laptops
│   │                    #  only (sudo, SYSFILE row); never linked, never in symlinks.sh
│   ├── xdg-desktop-portal/ # portals.conf — names the gtk backend (a dwm session sets no XDG_CURRENT_DESKTOP); symlinked
│   ├── dunst/, picom/   # base configs — COPIED by the installer, never symlinked (theming engine rewrites them)
│   └── theme/templates/ # .dcol templates: always/ (every wallpaper change), theme/ (theme switch only)
│                        # NOTE: there is deliberately no config/fastfetch/ or config/gtk-3.0/ —
│                        # those two configs are written ONLY by their templates (see docs/THEMING.md)
├── assets/
│   ├── cursors/         # vendored upstream cursor tarball + its .sha256 + LICENSE.Bibata
│   ├── fonts/           # Cascadia Code NF, repacked from the upstream zip (reproducible; README.md) + .sha256 + OFL
│   └── themes/          # Adwaita-dark/gtk-3.0/gtk.css — the GTK3 shim gnome-themes-extra used to ship (README.md)
│                        # (neither Fedora nor Void packages Bibata; see that dir's README.md before touching it)
├── scripts/
│   ├── dots                    # THE user-facing command, symlinked to ~/.local/bin/dots by the restore stage.
│   │                           # Thin dispatcher; its SUBCOMMANDS table is the ONLY declaration of the
│   │                           # subcommand list — --help, the zsh completion and tests all read it back.
│   ├── install-void.sh       # THE installer: thin orchestrator dispatching to the 4 stages below (+ --skip-suckless, --dry-run, --only-<stage>)
│   ├── install-live.sh         # scope J (docs/LIVE-INSTALL.md): run as root ON THE LIVE ISO — picks and ERASES a disk
│   │                           # (typed name, or DISK= + WIPE=), GPT + optional LUKS2 root + mkfs + mount at /mnt, zram + swapfile,
│   │                           # base-system + linux + linux-lts, config, user in wheel, GRUB (UEFI or BIOS),
│   │                           # then dots, unmount, reboot. Refuses without root=live: on the cmdline.
│   │                           # --target DIR (a root you mounted; no disk erased), --answers FILE (unattended),
│   │                           # --skip-dots, --reboot, --dry-run.
│   ├── install-live-{disk,part,swap}.sh # sourced by it (J-3): which disks may be erased + the picker, the
│   │                           # sfdisk layout read back by PARTN + PARTLABEL (never vda1-style names), the
│   │                           # swapfile size and zramen's conf. A re-run resumes a target already mounted
│   │                           # from this disk's dots-root rather than erasing it again.
│   ├── install-live-luks.sh    # sourced by install-live-answers.sh (J-4): optional LUKS2 (argon2id) on dots-root,
│   │                           # opened as luks-<UUID> (dracut's own name), passphrase on stdin only (dialog, or
│   │                           # LUKS_PASSFILE: root's, 0600). dracut's crypt module + rd.luks.uuid= and
│   │                           # rd.vconsole.keymap= in GRUB_CMDLINE_LINUX. NO crypttab: runit's crypt.awk
│   │                           # would luksOpen root a second time. Mappings on the disk closed before a re-layout.
│   ├── install-live-{answers,validate,base,config,dots}.sh # sourced by it: dialog menus / answers parser +
│   │                           # validators, preflight + xbps-install -r bootstrap, xchroot config + grub-install,
│   │                           # ~/dots clone + install-void.sh as the user under a TEMPORARY NOPASSWD rule
│   │                           # (EXIT trap). xchroot's exit status is not trusted for that run: a marker file
│   │                           # is, and processes left rooted in the target are stopped by /proc/<pid>/root.
│   │                           # On every exit, Ctrl-C included, they are stopped BEFORE the rule goes; each
│   │                           # script install-void.sh runs calls stop_on_interrupt (global_fn.sh).
│   ├── install-pre.sh          # stage: sanity checks (xbps present, sudo available, in wheel; musl noted)
│   ├── install-pkg.sh          # stage: full upgrade, then xbps packages (packages/*.lst), then repos + drivers
│   ├── install-pkg-tiers.sh    # sourced by install-pkg.sh: install_tier — ONE xbps transaction per tier;
│   │                           # names not in the index (xbps-query -R) are failed BEFORE it, since one
│   │                           # unknown name aborts the whole transaction; per-package retry if it fails
│   ├── install-pkg-xbps.sh     # sourced by install-pkg.sh: sync, update xbps, full -u upgrade before any install
│   │                           # (Void has no partial upgrades; user decision 2026-10-15, every run)
│   ├── sysfile-lib.sh          # sysfile_install: the SYSFILE contract (root-owned copies), shared by the
│   │                           # touchpad snippet (drivers-laptop.sh); uninstall-sysfiles.sh is the other half
│   ├── install-pkg-repos.sh    # sourced by install-pkg.sh: Void's nonfree repo (void-repo-nonfree) + sublime-text4,
│   │                           # then drivers_install (`dots drivers`). A REPO row only if it enabled nonfree
│   ├── install-restore.sh      # stage: ZDOTDIR + symlinks.sh + dots symlink + theme deploy + app configs + zinit/TPM bootstrap clones
│   ├── install-restore-bin.sh  # sourced by install-restore.sh: the ~/.local/bin/dots symlink + its SCRIPT manifest row
│   ├── install-restore-theme.sh # sourced by install-restore.sh: theme base-config deploy + manifest + backup
│   ├── install-restore-gtk3-shim.sh # sourced by install-restore-theme.sh: copies assets/themes/Adwaita-dark to ~/.local/share/themes
│   ├── install-restore-theme-active.sh # sourced by install-restore-theme.sh: theme_active — what a re-run re-applies
│   │                                   # (--wallbash or theme.set's theme, whichever is newer; dark only when neither)
│   ├── install-restore-vendored.sh # sourced: shared select/verify/extract/claim for assets/*/ tarballs
│   ├── install-restore-font.sh  # sourced by install-restore-theme.sh: extracts the vendored Cascadia Code NF
│   │                            # into ~/.local/share/fonts (THEME row; no fc-cache — see its header)
│   ├── install-restore-cursor.sh # sourced by install-restore-theme.sh: extracts the vendored cursor tarball
│   │                             # into ~/.local/share/icons and claims it as a THEME row
│   ├── install-restore-theme-identity.sh # the identity writers: render a theme.conf into settings.ini + xsettingsd.conf
│   │                                     # sourced by BOTH install-restore-theme.sh and scripts/theme/theme-apply.sh
│   ├── install-restore-apps.sh  # sourced by install-restore.sh: thunar/xfce4/mimeapps deploy + guarded xfconf pass
│   ├── install-restore-flatpak.sh # sourced by install-restore.sh: Flathub remote (--user) + read-only global overrides
│   ├── install-restore-pipewire.sh # sourced by install-restore.sh: ~/.config/pipewire/pipewire.conf.d links to the
│   │                             # wireplumber + pipewire-pulse examples (LINK rows; uninstall-pipewire.sh reverts)
│   ├── install-restore-wallpapers.sh # sourced by install-restore.sh: shallow-clones the wallpaper repo into
│   │                             # <pictures>/wallpapers/dots (WALLPAPERS row; DOTS_WALLPAPER_REPO= skips it);
│   │                             # wallpaper.sh sources it for wallpaper_collection_dir. No image is committed here.
│   ├── install-services.sh     # stage: login shell to zsh (sudo usermod) + runit services + groups + ly on tty2
│   ├── install-services-runit.sh # sourced: SERVICE/SERVICEOFF rows; dbus, elogind, NetworkManager, bluetoothd
│   │                             # (dhcpcd/wpa_supplicant off only once NM is enabled); tty2's getty handed to ly
│   ├── install-services-groups.sh # sourced: usermod -aG network,bluetooth,kvm,video (D4; never reverted)
│   ├── install-services-ly.sh  # sourced: ly v1.4.1 built from source — pinned commit, vendored deps, zig 0.16.0
│   │                           # tarball by sha256 (tests/ly-pins.sh); LYBUILD ly <path> rows; uninstall-runit.sh reverts
│   ├── install-services-ly-place.sh # sourced by it: placing (copy + rename, so a running ly never blocks it),
│   │                           # `META ly_build v<ver> <commit>`, and the rebuild when the pins move: config.ini
│   │                           # kept, paths the new ly lacks pruned with their rows, ly never restarted
│   ├── install-suckless.sh     # standalone builder: dwm/st/dmenu/dwmblocks/slock (called by the install stage unless --skip-suckless)
│   ├── running-build.sh        # sourced by install-suckless.sh, install-void.sh and dots doctor: a running dwm/dwmblocks
│   │                           # still on the binary an install replaced (/proc/<pid>/exe "(deleted)", content differs),
│   │                           # with the in-place restart for each. DOTS_PROC fakes /proc in tests
│   ├── install-session.sh      # sourced by install-suckless.sh: autostart.sh hook + ~/.xinitrc (both user-owned once they exist)
│   ├── install-session-template.sh # sourced by install-session.sh: the autostart.sh BODY (display / daemons / services parts)
│   ├── install-session-template-applets.sh # sourced by the template: the desktop-applet part (polkit, blueman, nm-applet, xdg-user-dirs)
│   ├── install-session-report.sh # sourced by install-session.sh: what to tell someone who already HAS an autostart.sh
│   ├── install-session-report-applets.sh # sourced by the report: the second half of its daemon list
│   ├── install-session-report-xinitrc.sh # sourced by the report: the paste lines for an existing ~/.xinitrc
│   ├── symlinks.sh             # symlinks the safe config/ dirs into ~/.config, backs up conflicts (--restore [timestamp] to undo)
│   ├── uninstall.sh            # + uninstall_steps.sh, uninstall-apps.sh, uninstall-theme.sh, uninstall-flatpak.sh, uninstall-pipewire.sh, uninstall-repos.sh, uninstall-runit.sh, uninstall-wallpapers.sh, uninstall-sysfiles.sh — manifest-driven removal
│   ├── version.sh, migrate.sh  # + global_fn.sh, migrations/ — versioning and migration framework
│   │                           # (migrations/0.1.0-to-0.2.0.sh: the first real one — stale generated headers;
│   │                           #  0.2.0-to-0.3.0.sh is a no-op, still REQUIRED: migrate.sh stops at a missing step;
│   │                           #  0.4.0-to-0.5.0.sh removes the vendored nsxiv build its manifest row records)
│   ├── update.sh               # `dots update`: refuse if unsafe, git pull --ff-only, then re-run install-void.sh
│   ├── drivers.sh              # `dots drivers`: GPU VA-API driver, kernel-requested firmware, microcode, fwupd;
│   │                           # NVIDIA REPORT-ONLY (user decision 2026-10-13). Logic in drivers-lib.sh +
│   │                           # drivers-{detect,gpu,firmware,laptop}.sh, which install-pkg-repos.sh also sources.
│   │                           # SYSFILE rows (root-owned copies, e.g. the touchpad snippet): replaced/removed only
│   │                           # while unedited (file_matches_history) — uninstall-sysfiles.sh
│   ├── doctor.sh               # `dots doctor`: read-only health report, human or --tsv from one report();
│   │                           # checks in doctor-checks.sh / doctor-session.sh / doctor-daemons.sh /
│   │                           # doctor-portal.sh / doctor-notify.sh (dunst answers, DND left on) / doctor-drivers.sh,
│   │                           # every list read from its source
│   └── theme/                  # theming engine: colorgen.sh, apply-templates.sh, reload.sh, wallpaper.sh, wallpaper-default.sh, theme-apply.sh,
│                               # ly-theme.sh (`dots login-theme`: five keys of root's /etc/ly/config.ini, default_input included; sudo, never prompted without a TTY)
│                               # theme-lock.sh: sourced by wallpaper.sh + theme-apply.sh — one change at a time (`flock -o`,
│                               #  so dwmblocks and the other daemons a change starts never hold the lock; --list, help,
│                               #  --login-random and --select's picker take none). wallpaper-login-random.sh: sourced by wallpaper.sh
├── packages/            # four tiers + laptop.lst; tests/pkglist.sh globs them, never names them
│   ├── core.lst         # hard-fail — the installer's own next step breaks (git, zsh)
│   ├── build.lst        # suckless build deps — read by install-suckless.sh ONLY, not install-pkg.sh
│   ├── desktop.lst      # never aborts, but each failure is repeated in a red closing summary;
│   │                    # the trailing '#' on each line IS that package's consequence text
│   ├── extra.lst        # best-effort applications and conveniences
│   ├── laptop.lst       # `# chassis: laptop` — installed by drivers-lib.sh on laptops ONLY (rule 10)
│   └── live/            # base.lst + uefi.lst: what install-live.sh puts in the TARGET root. A subdir so dots
│                        #  doctor's depth-1 glob never checks them; pkglist.sh, void-pkgnames.sh and ci.yml glob it too
├── suckless/
│   ├── dwm/, st/, dmenu/, dwmblocks/, slock/
│   └── */patches/      # vendored .diff files per program + PATCHES.md — a RECORD; the sources are pre-patched
├── themes/              # static themes: dark, gruvbox, nord, tokyo-night + CREDITS.md
├── tests/               # the suite; `ls tests/*.sh` is the list, deliberately not restated here.
│                        # CI globs it, so a new test is picked up with no wiring.
│                        # tests/lib/ holds SOURCED helpers, outside that depth-1 glob — never tests.
│                        # tests/fixtures/ holds captured real-tool files (ly's config.ini), same reason.
├── .github/workflows/   # ci.yml — lint / tests / build-suckless / package-names (Void container jobs)
│                        # install-container.yml — the only job that RUNS install-void.sh (paths-filtered)
├── docs/                # THEMING.md, THUNAR.md, UNINSTALL.md, FONTS.md, HARDWARE.md
├── KEYBINDINGS.md       # every dwm and sxhkd binding
├── HyDE/                # untracked local clone of HyDE-Project/HyDE — reference only, not part of this repo
├── dwm-titus/           # untracked local clone of ChrisTitusTech/dwm-titus — reference only; see Reference clones
├── ROADMAP.md           # comparison doc vs. HyDE; see Roadmap status below
└── .claude/
    ├── changes/         # dated change logs (session-protocol.md governs this)
    ├── tasks/           # MASTER_PLAN.md + scope files + per-task folders
    └── state/
```

**Entry points**: two installers, one for each starting point.
`scripts/install-live.sh` runs on the Void live ISO, erases a disk, installs
Void, then runs `install-void.sh` inside it (scope J; `docs/LIVE-INSTALL.md`).
`scripts/install-void.sh` is the desktop installer itself — run it on a fresh
Void base install to get
the full desktop (zsh/tmux + X11 + dwm/st/dmenu/dwmblocks/slock + ly). It's a
thin orchestrator over four idempotent, independently-runnable stages (pre ->
install -> restore -> services — `scripts/install-{pre,pkg,restore,services}.sh`);
`--only-<stage>` runs a single stage, `--dry-run` threads through every
stage without mutating anything. `scripts/install-suckless.sh` (re)builds
just the suckless programs standalone (also `--dry-run`-aware); `scripts/symlinks.sh`
(re)links shell config without touching packages (also `--dry-run`-aware).

After an install, **`dots` is the single user-facing command** (symlinked to
`~/.local/bin/dots`) — `dots theme`, `dots doctor`, `dots update` and the
rest; `dots --help` is the list, rendered from the one SUBCOMMANDS table in
`scripts/dots` (this paragraph used to restate it and went stale when
`update` was added, 2026-10-12). It only forwards — every target script
stays independently runnable. It deliberately breaks rule 3: because it is reached through a
symlink, `cd "$(dirname "${BASH_SOURCE[0]}")"` would resolve `~/.local/bin`
rather than the repo, so it uses `readlink -f` instead.

---

## Roadmap status

`ROADMAP.md` was written by diffing this repo against HyDE-Project/HyDE and
is **partly stale** — treat it as a backlog of ideas, not a source of truth
for current state.

**Already done, ahead of what ROADMAP.md assumes:**
- A single installer (`scripts/install-void.sh`; Fedora Server's until the 2026-10-15 port, when Workstation had already been dropped as a target) — ROADMAP.md's §9 priority list treats "package lists + dnf installer" as not-yet-started; it already exists. **Scope note:** this repo previously also shipped `install-arch.sh`, `install.sh` (Debian/Ubuntu), `install-macos.sh`, and a separate `install-void-server.sh` — all four were dropped in favor of one Fedora-only installer (see `.claude/changes/` for the dated log). ROADMAP.md's Arch-comparison framing and any lingering references to those scripts elsewhere in this file predate that decision. **Since 2026-10-15 that one installer is Void-only** (the port), and scope J added `install-live.sh` in front of it.
- dwm, st, dmenu, dwmblocks, and slock are all vendored *and* patched — ROADMAP §2.5 lists this as a "to do" with only a subset of patches recommended. The roster is 27 diffs for dwm (actualfullscreen, autostart, **bidi**, cfacts, **dragtile**, **dropterm**, **dynamicscratchpads**, hide_vacant_tags, pertag, placemouse, **preservecfact**, **preservepertag**, **preserveonrestart**, **replug**, resizepoint, restartsig, **scratchpadgroup**, **sharetags**, **snapwindows**, status2d, status2d-systray, **statusallmons**, statuscmd, statuscmd-status2d, systray, **wakeonsignal**, xresources), 10 for dmenu (**bidi**, border, caseinsensitive, center, fuzzymatch, lineheight, mousesupport, numbers, **pathcache**, xresources), and one each for st (xresources-signal-reload), dwmblocks (statuscmd) and slock (xresources). Each program's `patches/PATCHES.md` is the authoritative per-patch record; `ls suckless/*/patches/*.diff` is the source of truth for the list itself. The `*-local.diff` ones were captured against this tree rather than fetched from suckless.org, because they could not apply cleanly on top of the others.
  - **A dwm restart no longer scatters the desktop (2026-10-07).** `reload.sh` SIGHUPs dwm on every wallpaper change; `preserveonrestart` hands tags, view, stash, floating geometry and focus to the re-exec'd instance. `dropterm` (`Super+grave`) is a drop-down terminal built on dynamicscratchpads, so it survives restarts too. `tests/dwm-runtime.sh` covers both, and checks every floating class in `rules[]` actually floats. **`wakeonsignal` (2026-10-12)** makes dwm act on SIGHUP/SIGTERM at once: it used to wait for the next X event, so the VM's power-menu logout took 20-25 s. The runtime test no longer fakes an event to wake dwm. **`preservepertag` (2026-10-12)** adds each tag's layout, mfact, nmaster and bar, and Mod+Tab's history, to what a restart keeps.
  - **Hyprland-style mouse (2026-10-22).** `Super` + left-drag drops a tiled window into another slot and keeps it tiled (placemouse); `Super` + right-drag resizes a floating window from the grabbed corner with no pointer warp (resizepoint) and, on a tiled one, moves the master split and the window's nearer edge (cfacts + **dragtile**, which retired dragmfact); floating windows snap to each other (**snapwindows**). cfact survives a restart (**preservecfact**).
  - **`scratchpads` was replaced by `dynamicscratchpads` on 2026-08-07** and the two are mutually exclusive (both claim bit `LENGTH(tags)` of the tag bitmask). Scratchpads are now assigned dynamically from the focused window rather than pre-declared as commands.
- `install-suckless.sh` is the rebuild/build entry point already, doing the job ROADMAP §6 assigns to a not-yet-written `rebuild.sh`.
- Idempotent, re-runnable installers with colored logging and backup-on-conflict symlinking already exist — ROADMAP §2.1/§2.3 describe this as future infrastructure to add.
- Launcher, powermenu, and clipboard manager are done via dmenu (not rofi) — `Super+space` (`config/dwm/bin/dwm-apps`, a drun-style list of `.desktop` entries — `dmenu_run` on `Mod+p` until 2026-10-13), `Super+Shift+x` (`config/dwm/bin/dwm-powermenu`), `Super+v` (`config/dwm/bin/dwm-clipmenu`, a thin wrapper around `clipmenu`/`clipnotify`). ROADMAP.md's comparison table and package list have been updated to match — dmenu was chosen over rofi to keep a single menu tool. clipmenu was COPR-only on Fedora (an explicitly approved auto-enable); on Void it is a plain `desktop.lst` package from the main repo.

**Also done, superseding earlier "pending" entries (roster Epic, 2026-08-06/07 — scope file `.claude/tasks/scope-b-app-roster-finalization.md`):**
- **Screenshot and lock/idle both landed** (ROADMAP §3 is stale on this): `maim` + `slop` behind a dmenu mode menu in `config/dwm/bin/dwm-screenshot`, and `xss-lock` + `xset` + slock behind `config/dwm/bin/dwm-lock`. Both bound in `config/sxhkd/sxhkdrc`.
- alacritty is the main terminal (st retained as the no-GPU fallback); thunar is finalized with archive/thumbnail/mime defaults; the status bar runs 13 blocks plus the systray (NET added 2026-10-05; DND, empty unless dunst is paused, 2026-10-07; BAT, empty without a system battery, 2026-10-13 — the DND block became an always-visible notification button on 2026-10-15, opening `dwm-notify`); picom is performance-tuned; the prompt is starship and fastfetch is the fetch tool. Both of the last two are themed from the wallpaper.
- **README.md is no longer a stub** — it carries the CI badge and the pre-commit setup.

**Roster gap-fill Epic closed 2026-08-12** (scope file
`.claude/tasks/scope-c-roster-gap-fill.md` — locked decisions live there):
xsettingsd, udiskie, autorandr, `dwm-colorpicker` (`Super+c`) and `dwm-display`
(`Super+Shift+d`). **ROADMAP §3's status column was reconciled at the same time and
§9 is entirely done** — treat `MASTER_PLAN.md` as the queue, not ROADMAP.
Two §3 rows were left open *by decision*, not omission, and **both have since
landed at the user's request**: the blue-light filter (`dwm-nightlight`,
2026-10-05) and `xdg-desktop-portal-gtk` (2026-10-06 — a DECISION REVERSAL of
scope C's locked decision 5; it pays off without Flatpak through the Settings
portal's dark preference). See `ROADMAP.md` §3 for what that decision got wrong.
**Flatpak integration followed the same day** (scope file
`.claude/tasks/scope-e-flatpak-integration.md`): Flathub plus four read-only
`flatpak override --user` filesystem grants, under the same write-if-absent /
revert-if-unchanged contract as the dconf row. **Do not add `GTK_THEME`** — it
was chosen first and reversed (decision 5 there): it is a GTK debugging
variable that breaks GTK4/libadwaita Flatpak layouts. `flatpak` cannot unset
one global grant, so `uninstall-flatpak.sh` edits the override keyfile itself;
`tests/flatpak-integration.sh` checks that edit against a real flatpak when
one is installed. **`xcolor` was not a Fedora package** — §3 named it for years; only
`texlive-xcolor`, a LaTeX package, existed. The colour picker is a script.
Void does package `xcolor`; the script stays by user decision (2026-10-19).

**Laptops are a target too (scope-h, opened 2026-10-13)** — a DECISION
REVERSAL of scope-b locked decisions 9 and 12, which made this desktop-only.
A desktop keeps exactly its old behaviour; laptop behaviour activates only
where `drivers_chassis` (`scripts/drivers-detect.sh`) says laptop. Since
2026-10-14 a virtual machine reads as `vm` (winning over any chassis type or
battery a hypervisor exposes) and gets desktop behaviour; bare metal reporting
an odd chassis type is `unknown`, also treated as a desktop. On Void (I-7,
2026-10-15) "vm" comes from the kernel's `hypervisor` CPU flag plus the DMI
vendor, not `systemd-detect-virt`; `dwm-picom` sources the same
`drivers_virt`, so the two cannot disagree.
Landed so far: the checker, `packages/laptop.lst`, the real backlight in
`dwm-brightness` (block lamp `󰛨` vs sun `󰃟`; the words `BL`/`GAMMA` until the 2026-10-22 icon bar), the battery block with
low/critical alerts (`dwm-battery`, no daemon), and the touchpad snippet
(`config/xorg/`, an Xorg InputClass, not xinput), and power profiles
(`dwm-power`, which talks to the profiles D-Bus API with gdbus; served by
`power-profiles-daemon` and its runit service — `tuned-ppd` before the Void
port). All five scope-h slots are done
(`.claude/tasks/scope-h-laptop-support.md`). There is no laptop to verify
on, only the VM, so laptop paths are fixture-tested.

**Still genuinely pending (ROADMAP is accurate here):**
- No `.Xresources` **file** in the repo — deliberately: the theming engine generates `~/.cache/dots/theme/xresources` and `xrdb -merge`s it, so a static checked-in one would be immediately overwritten.
- `install-void.sh` has not been run end-to-end on real hardware (first recorded in `.claude/changes/archive/2026-08-04-fedora-arch-install-scripts-verify-fix.md`, written when an Arch installer still existed alongside it). VMs only: the Void VM runs and the live-ISO matrix above, plus the container job. Treat "it works on bare metal" as unproven.
- ~~The `core.lst` vs `extra.lst` split has never been reviewed as a whole.~~ **Done 2026-08-08** — reviewed as one pass and replaced with four tiers (see rule 10). The packages that back keybinds now sit in `desktop.lst`, whose failures are repeated in a red closing summary with what each one costs, so a failed install can no longer leave keys silently dead. Six packages that were declared nowhere are now declared: `libXext-devel`, `libXrandr-devel`, `libxcrypt-devel` and `ncurses` (they lived only in an inline array in `install-suckless.sh`), plus `procps-ng` and `desktop-file-utils`.

**Theming engine (added 2026-08-05, 7 sub-tasks — see `docs/THEMING.md`):**
- Dark-mode-only wallbash-style engine: wallpaper -> ImageMagick colour extraction (`scripts/theme/colorgen.sh`) -> `.dcol` palette -> template engine (`scripts/theme/apply-templates.sh`) -> live targets -> ordered reload (`scripts/theme/reload.sh`).
- dwm, st, dmenu and slock all read colours from the X resource database at runtime (xresources patches — see each tool's `patches/PATCHES.md`). nsxiv reads its `Nsxiv.*` resources natively, with no patch.
- User commands: `scripts/theme/wallpaper.sh` and `scripts/theme/theme-apply.sh`; the keybinds (`Super+Shift+w` picker, `Super+w` random, `Super+Shift+t` theme menu — remapped 2026-10-13) live in `config/sxhkd/sxhkdrc`, needing no dwm rebuild but depending on sxhkd being installed (it is in `desktop.lst`, so a failed install is reported loudly rather than silently) and running. They moved out of `config.def.h` in roster sub-task 4 and must not be re-added there — dwm and sxhkd both `XGrabKey`, and a doubly-bound key silently dies.
- **Four shipped static themes** — `dark` (Catppuccin Mocha), `gruvbox`, `nord`, `tokyo-night`. `config/theme/templates/` holds the `.dcol` templates. Every `colors.dcol` is **generated** by `colorgen.sh` from a four-block seed image, never hand-written, and each file's header records its seed hex so it can be regenerated; hand-written hex is how you get a palette missing a key some template references. **A static theme apply also renders a default wallpaper** from its palette (`scripts/theme/wallpaper-default.sh`, 2026-10-05). No image is committed, and a `~/.fehbg` the user set is never replaced. **A theme switch applies the theme's identity too** (GTK theme name, icons, cursor, font) via the writers in `install-restore-theme-identity.sh` — `theme.conf` was report-only until 2026-08-12. Those writers never touch a `settings.ini`/`xsettingsd.conf` the manifest does not claim as ours, and only a *switch* (not an installer re-run) replaces one it does. All four `theme.conf` files currently carry identical values because the repo declares exactly one dark GTK theme; that is a packaging limit, not a design one. **That theme, `Adwaita-dark`, is NOT a GTK3 built-in** (only GTK4 aliases it): when Fedora 44 retired `gnome-themes-extra`, GTK3 apps silently fell back to *light* Adwaita until the one-line shim in `assets/themes/` was vendored (2026-10-06). Void does package `gnome-themes-extra` (its `Adwaita-dark/gtk-3.0/gtk.css`, read from the 3.28_4 .xbps on 2026-10-19), byte-identical to the shim; the installer does not install it, and the shim stays by user decision (2026-10-19). Do not "fix" this by renaming to `Adwaita` — plain GTK4 apps would lose their alias and go light. `tests/gtk3-adwaita-dark-shim.sh` fails the build if a `gtk_theme` is neither a GTK3 built-in nor a shim. `tests/theme-identity.sh` guards the whole path. **`cursor_theme` is the one identity field backed by a vendored asset** rather than a package: `assets/cursors/` holds the upstream Bibata tarball and `install-restore-cursor.sh` unpacks it. The name in all four `theme.conf` files must match the archive's top-level directory — nothing at runtime notices when they disagree (GTK silently falls back to a default cursor), so `tests/cursor-theme.sh` reads both sides and fails the build instead.
- **`config/dunst` and `config/picom` must never be added to `symlinks.sh`** — the engine rewrites those whole files on every wallpaper change, and a symlink would make it write into this repo. The installer copies them instead.
- **Templates as of sub-task 9** (`always/`): `xresources`, `dunst`, `picom`, `gtk`, `statusbar`, `alacritty`, `starship`, `fastfetch`, `vim`, `gtk2` (2026-10-06 — writes `~/.gtkrc-2.0`; Fedora 44 packaged no dark GTK2 theme, and lxpolkit is GTK2. Void's `gnome-themes-extra-gtk` has a GTK2 `Adwaita-dark` with fixed colours, not installed: the template stays by user decision, 2026-10-19, because it follows the wallpaper). `cava.dcol` was **deleted** — it themed a program the installer never installs. Adding a template means reading `config/theme/templates/always/README.md` first: it documents the three target styles and, more importantly, which one is safe for a config that `symlinks.sh` links.
- **`gtk.css` and `fastfetch/config.jsonc` have no static copy under `config/` at all** — the `.dcol` is the sole authored version. That avoids the two-files-in-lockstep hazard `picom` has (where `config/picom/picom.conf` and `picom.dcol` must be hand-edited together or the first wallpaper change reverts the tuning), at the cost of two obligations on `install-restore-theme.sh`: create the parent directory, or the engine's install-check skips the template forever; and claim the path in the manifest, or uninstall cannot remove it. **Do not add a `config/fastfetch/` directory** — it would reintroduce exactly the lockstep problem.
- **`xsettingsd.conf` is written by the installer, NOT by a template** — `theme_write_xsettingsd_conf` in `scripts/install-restore-theme-identity.sh`. It carries the GTK theme identity from the active theme's `theme.conf` (`themes/dark/` by default; a switch re-renders it from the selected theme) plus the Xft rendering keys (`Xft/Antialias`, `Xft/Hinting`, `Xft/HintStyle`, `Xft/RGBA`), which live nowhere else in this repo — `xresources.dcol` is colours only. None of it is palette-derived, so a `.dcol` would re-render an identical file on every wallpaper change. `Xft/DPI` is deliberately omitted: hardcoding `96*1024` would override X's autodetection and break HiDPI. It is still in `reload.sh`'s sweep (`pkill -HUP`) so an installer re-run or a `theme.conf` edit needs no logout. **xsettingsd has no CSS channel** — it plays no part in the wallpaper accent colours, which are `gtk.css` and reload on their own.
- **starship is themed by splicing, not by regenerating.** `config/starship/starship.toml` is the authored config and stays symlinked; `starship.dcol` renders only its `[palettes.dots]` table, and the post-command writes a combined copy to the cache that `conf.d/99-prompt.zsh` prefers while it is newer. The marker line `# ### dots-theme palette ###` in `starship.toml` is load-bearing — it is where the splice cuts, and the template refuses to touch a config that lacks it.

When picking up ROADMAP.md work, re-check the relevant section against the
actual repo state first — don't assume an item is undone just because it's
listed there.

---

## Reference clones

Two untracked clones sit in the repo root as comparison sources. Rule 9 governs
both: read-only, never referenced from a script, never assumed present.

### `HyDE/` — HyDE-Project/HyDE

Arch + Hyprland + Wayland. The source `ROADMAP.md` was diffed against, and the
origin of the framework-parity queue items in `MASTER_PLAN.md`. Different
platform, different display server — borrow *structure*, not implementation.

### `dwm-titus/` — ChrisTitusTech/dwm-titus (cloned 2026-08-24, HEAD `e1f884e`)

The closest external project to this one: **Fedora-only, X11, dwm, bash
installer** — the platform contract dots had until the 2026-10-15 Void port,
the same window manager, and the same "one installer on a fresh box" goal. Docs at <https://dwm.christitus.com>.
It is much further along on desktop shell and on validation, and it reaches
several of the same ends by opposite means. Know these before comparing
anything:

- **Its patches are not vendored as `.diff` files.** It is a maintained hard
  fork carrying patched code directly in `dwm.c` (5.7k lines);
  `docs/PATCH-OWNERSHIP.md` records per-subsystem owners and invariants in place
  of a patch series. That is the inverse of rule 5 — its `dwm.c` is not a source
  you can lift from without deciding the re-vendor story first.
- **Runtime config is TOML, hot-reloaded.** `config/{hotkeys,themes,window-rules}.toml`
  are parsed by a vendored `tomlparser.c` linked into dwm and re-read on
  `SIGUSR1` *and* on inotify writes to the config dir — keybinds, colours,
  border width and window rules all change with no rebuild. dots keeps keybinds
  in `config.def.h` + sxhkd and colours in generated xresources: a different
  trade against the same problem.
- **Its shell layer is Quickshell (QML/Qt6)** — panel, launcher, control center,
  settings, notifications, network/bluetooth/audio/power — not dwmblocks +
  dmenu. Most of its `scripts/` and over half its tests exist to serve that
  layer, and the Qt dependency is exactly what this repo is built to avoid.
- **It ships an ISO** (`dwm-fedora.ks`, `dwm-fedora-nvidia.ks` +
  `scripts/build-dwm-fedora-installer-iso.sh`), and targets Fedora 44. dots
  pinned oldest-supported Fedora; on Void, a rolling release, there is no
  version to pin. dots has its own live-ISO installer since scope J
  (`install-live.sh`), though it builds no ISO.
- `ls dwm-titus/tests/*.sh` and `grep -n '^check-' dwm-titus/Makefile` are the
  source of truth for its suite and its gates. Do not restate either here.

**Where it was ahead of dots, and what has been harvested since** (this list
said "dots has never executed dwm in a test" until 2026-10-06, a month after
that stopped being true — check the repo before repeating any of it):

- dwm exercised **live under Xvfb** — ✅ harvested 2026-09-03 as
  `tests/dwm-runtime.sh` (EWMH root state plus four vendored patches), run by
  the `build-suckless` CI job.
- An install manifest **proved, not maintained** — ✅ harvested 2026-09-28 as
  `tests/install-uninstall-symmetry.sh`: restore twice, uninstall, and the
  sandbox HOME must be byte-identical apart from the documented leftovers.
- CI installing dependencies from **the repo's own package map** — ✅
  harvested 2026-09-03 (`tests/ci-build-deps.sh`; `ci.yml` reads
  `packages/build.lst`).
- A **hardened test runner** — ✅ harvested 2026-09-03 (`tests/run-tests.sh`:
  `setsid`, workspace cleaned on every exit path).
- **Human and machine-readable diagnostics from one code path** — ✅
  harvested 2026-10-06 as `dots doctor` (`scripts/doctor.sh`, `--tsv`).
- Project docs: `CHANGELOG.md`, `CONTRIBUTING.md` and Dependabot exist here
  too; **`SECURITY.md`, `SPEC.md` and `docs/RELEASING.md` still do not.**
- **Still not harvested, by decision:** runtime TOML config with hot reload
  (an Epic the user has not asked for) and the Quickshell/Qt6 shell layer
  (rejected — see scope D's out-of-scope list).

**Where dots is ahead:** wallpaper-derived theming (dwm-titus palettes are
hand-written in `themes.toml`), the four-tier package model with per-package
consequence text, `.diff` patch vendoring that survives a re-vendor, and a far
smaller dependency surface.

---

## Project-specific rules

These are conventions already established across `scripts/*.sh` — follow
them for any new or edited installer/build script rather than inventing a
new pattern.

1. **Every script is idempotent and re-runnable.** `set -euo pipefail` at the top; re-running after a partial or full success must be a safe no-op (or converge to the same state), never error out or duplicate work.
2. **Colored logging helpers, not raw `echo`.** Each script defines its own `red()`/`green()`/`yellow()`/`blue()` (`printf '\033[3xm%s\033[0m\n'`) — red for hard errors, green for confirmed/success/already-ok, yellow for warnings/manual-follow-up, blue for informational. Reuse this pattern verbatim in new scripts rather than introducing a different color scheme or a shared sourced file.
3. **`SCRIPT_DIR`/`DOTS_DIR` resolution pattern.** Every script computes its own location and the repo root the same way: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then `DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"`. Never hardcode paths.
4. **Packages outside Void's main repo are never silently attempted.** If a package exists only in a repository the installer does not enable, leave it out of `packages/*.lst` (tests/void-pkgnames.sh fails on a nonfree-only name), add a header-comment note with the exact command, and print a closing yellow reminder. **Vendoring is the other option**, taken for the Bibata cursor theme (2026-08-13) and Cascadia Code NF (2026-10-15): the pinned artifact lives in `assets/<kind>/` with its checksum and license, and the restore stage unpacks it through `install-restore-vendored.sh` — no extra repo, no network at install time. It is only worth it for a self-contained asset; don't vendor anything that needs building or linking. Enabling any repository beyond Void's main one is a trust decision left to the user — never by default, only after an explicit ask. **The authorised ones:** (1) **Flathub** (`install-restore-flatpak.sh`, `--user`, 2026-10-06): a FLATPAK row only when the remote did not already exist, and `dots uninstall` removes it only while no installed ref comes from it. (2) **Void's nonfree repository** (`install-pkg-repos.sh`), for **sublime-text4**, the default editor (Sublime Text authorised 2026-10-13; nonfree as its source since the Void port, 2026-10-15). Same contract as Flathub: a REPO row only when this run installed `void-repo-nonfree`, and uninstall removes it only while no installed package comes from nonfree. RAR stays on `unar` (main); nonfree being enabled does not reopen locked decision 8. (The Fedora-era exceptions — the clipmenu COPR, Sublime HQ's rpm repo, RPM Fusion — are gone: Void's main repo has clipmenu and a full ffmpeg.) "Don't vendor anything that needs building" has no exception now: **nsxiv**, vendored 2026-10-13 because Fedora did not package it, is Void's package since 2026-10-19 (user decision; the same upstream v34 with the default config), and `suckless/nsxiv/` is gone. An existing install's `/usr/local` build, which would shadow `/usr/bin/nsxiv`, is removed on upgrade by the 0.4.0 → 0.5.0 migration (`scripts/migrations/0.4.0-to-0.5.0.sh`).
5. **Suckless patches are vendored as `.diff` files under `suckless/<program>/patches/`**, named `<patch>-<version-or-date>-<hash>.diff`, **as a record — nothing applies them.** The vendored `.c`/`.h` sources are already patched — each diff was merged into them once, when it was vendored (some by a clean `patch -p1`, the ones that conflicted by hand, as each `PATCHES.md` entry records) — the build is plain `make`, and no `patch(1)` or `git apply` call exists in `scripts/`, `tests/`, `.github/` or any suckless `Makefile`. `suckless/<program>/patches/PATCHES.md` is the authority on what each patch is and how it was merged. A change to a patched behaviour therefore goes into the sources **and** its `.diff` + `PATCHES.md` entry in the same commit, so the tree could be rebuilt from upstream plus the recorded diffs; the `*-local.diff` files are diffs captured against this tree because they could not apply cleanly on top of the others. Don't turn this into a build-time apply step — the `*-local` diffs are exactly why that cannot work. (Until 2026-09-28 this rule claimed `install-suckless.sh` applied the diffs at build time; it never did.)
6. **`install-suckless.sh` never overwrites user customizations** — `autostart.sh` and `.xinitrc` are treated as user-owned once they exist; preserve that guarantee in any change to the build/install flow.

    **Adding an autostart entry is a three-place change**, and all three are enforced: the launch line in one of the `session_autostart_*` parts (in `install-session-template.sh`, split off from `install-session.sh` at the 250-line cap, and the desktop-applet part in `install-session-template-applets.sh`, split again 2026-10-07), a matching `session_report_daemon` call (`install-session-report.sh` or its `-applets.sh` sibling) so existing installs — whose `autostart.sh` is user-owned and never rewritten — are told what to paste, and the name in `DAEMONS` in `tests/autostart-daemons.sh`. That test RUNS both sides rather than parsing them and has caught an unpaired entry unprompted more than once, so skipping any of the three fails the build rather than shipping a daemon nobody launches. The template is split into parts purely for the 60-line function cap; the test calls only `session_autostart_template` and `session_autostart_report`, so splitting it again costs the test nothing. **Do not re-add an enumerated daemon list anywhere else** — the user-facing "wrote autostart.sh" message used to carry one and had already gone stale.

    **`~/.xinitrc` starts the session D-Bus bus** (Void, 2026-10-15): with no bus it re-runs itself under `dbus-run-session` before anything else, then hands DISPLAY to D-Bus activation and starts `pipewire` (which starts WirePlumber and pipewire-pulse through the two links `install-restore-pipewire.sh` makes). Void has no systemd user manager, so without that bus no portal, no PipeWire and no notifications start. On Fedora the same job was `dots-session.target` (2026-10-06), a systemd user unit binding `graphical-session.target`; it is deleted. The lesson from then still holds: the xdg-portal-gtk work shipped with no portal running and nothing noticed, because `dots doctor` checked only the dconf key. `scripts/doctor-portal.sh` asks the bus, then the portal itself. Existing `.xinitrc` files get `session_xinitrc_report_session`'s paste lines (`install-session-report-xinitrc.sh`), which `tests/xinitrc-report.sh` holds equal to `docs/THEMING.md` § Desktop portal.

    **The theme is restored in `~/.xinitrc`, never in `autostart.sh`** (2026-10-05). dwm reads xresources once at startup, and the only way to re-theme a running dwm is `reload.sh`'s `kill -HUP` — a restartsig re-exec, after which dwm re-runs `autostart.sh`. A theme step there loops the session. `session_xinitrc_template` (`install-session.sh`) merges the cache or, on the first login after a headless install, runs `dots theme dark`; an existing `.xinitrc` gets `session_xinitrc_report` instead. `tests/xinitrc-theme.sh` runs the generated file. **An autostart daemon that holds no X connection outlives the session** (2026-10-07): `clipmenud` is a shell loop over `clipnotify`/`xsel`, and after logout it flooded ly's TTY with failures. `dots_session_end` in the `.xinitrc` template `pkill`s it on every exit path. That is why the template never `exec`s dwm. A new non-X daemon belongs in that function too — and so does an X client that only notices the server is gone on its next write: `dwmblocks` sleeps between bar updates, so after a quick re-login autostart's `pgrep` guard found the old copy and started none, leaving the bar empty (`dwm-6.8`); `dwm-nightlight daemon` is a shell loop and had the same flaw. Both are stopped there since 2026-10-07. A daemon that blocks on its X connection (sxhkd, picom, xsettingsd, the GTK applets) dies with the server and needs nothing. **`dwm-audiowatch` (2026-10-15, Void) is the one non-X daemon deliberately NOT in that function**: it follows `pactl subscribe` and exits when PipeWire stays gone for 10 s, and the function already stops PipeWire, so its lifetime is PipeWire's. A line for it would mean a fourth stop category in the existing-`.xinitrc` report for no gain. The function, `session_xinitrc_report_session` and `docs/THEMING.md` § Desktop portal carry the same block. **picom's backend is chosen by `config/dwm/bin/dwm-picom`**, which `autostart.sh` runs (2026-10-14; before that the `glxinfo` probe was pasted inline into the user-owned `autostart.sh`, so no fix could ever reach an existing install): `xrender` in any VM (`drivers_is_vm` semantics), `glx` only on bare-metal hardware 3D, overriding `picom.conf` — see `docs/THEMING.md` and `tests/picom-backend-probe.sh`. `dots doctor` warns when the running backend disagrees with `dwm-picom backend`.
7. **`symlinks.sh` links directories, not individual files**, and backs up pre-existing conflicting paths to `~/.dotfiles-backup/<timestamp>/` before linking — keep new config categories (e.g. a future `config/nvim/`) consistent with this backup-then-link behavior rather than a blind overwrite. `symlinks.sh --restore [timestamp]` reverses a backup: no timestamp lists what's available under `~/.dotfiles-backup/`, a timestamp removes the matching symlink(s) and moves the backed-up originals back — it never touches a target that isn't currently one of its own symlinks (skips with a warning instead of overwriting unknown state).
8. **Package names are checked against Void's repo index, by a test.** `tests/void-pkgnames.sh` holds every name in `packages/*.lst` against `tests/fixtures/void-x86_64-pkgs.tsv`, a snapshot of the official x86_64 index (main + nonfree). It fails on a name that is not a Void package, or that is only in nonfree, because the package stages run before nonfree is enabled. Refresh the snapshot with `tests/void-pkgnames.sh --refresh` (curl, zstd, tar, python3; never in CI); the test warns once it is over 90 days old. Existence is not meaning: when a Fedora name maps to a differently named Void package, read the package's file list (download the `.xbps` from `repo-default.voidlinux.org/current/` and `tar -t` it) for the binary or path the repo actually uses, as scope I's I-2 did for lxpolkit, nmtui, the Noto Arabic faces and ffmpeg's decoders. Record the method in the change log (per `session-protocol.md`). (Until 2026-10-15 this rule said: check by hand on packages.fedoraproject.org.)
9. **`HyDE/` and `dwm-titus/` are local, untracked reference clones** — comparison sources only (`HyDE/` for `ROADMAP.md`; `dwm-titus/` for the Fedora/X11/dwm questions in **Reference clones** above). Neither is part of this project: never edit them, symlink into them, or reference either from any script, and never assume they are present on another machine. Both are `.gitignore`d.
10. **Package names live in `packages/*.lst`, never as inline arrays in installer scripts.** Four tiers, each with a different failure mode — pick by asking *what breaks, and does it announce itself?*

    | List | Consumer | On failure |
    | ---- | -------- | ---------- |
    | `core.lst` | `install-pkg.sh` | **Aborts the run.** Only for things the installer's own next step needs unconditionally — `git` for the zinit/TPM clones, `zsh` for the login-shell step. Keep it tiny: rule 8 means these names are checked against a snapshot of the index (and by CI's `package-names` job), never against a live `xbps` on the target, so a rename here turns a degraded install into no install. |
    | `build.lst` | `install-suckless.sh` **only** | **Aborts the build stage.** The suckless toolchain and headers. `install-pkg.sh` deliberately does not read it — `install-void.sh` runs the build stage right after, without `--skip-deps`, so `--skip-suckless` needs no special handling anywhere. |
    | `desktop.lst` | `install-pkg.sh` | **Never aborts**, but every failure is repeated in a red closing summary. For packages whose absence is otherwise **silent**: a dead keybind, a daemon that never starts, a theming engine that cannot run. |
    | `extra.lst` | `install-pkg.sh` | **Never aborts.** Applications and conveniences; failures get one yellow line in the summary. |
    | `laptop.lst` | `drivers-lib.sh` **only**, on a laptop | **Never aborts**, best-effort like extra. Its `# chassis: laptop` header line is load-bearing: `pkg_list_chassis` reads it, so `dots doctor` (which globs every list) checks it only where `drivers_chassis` says laptop. A future chassis-limited list declares itself the same way; no consumer names it. (scope-h, 2026-10-13) |

    **The trailing `#` comment on a `desktop.lst` line is load-bearing** — it is that package's consequence text, and `load_consequences()` in `install-pkg-tiers.sh` reads it back out to build the summary. `read_pkg_list()` already strips trailing comments, so the install path is unaffected and the fact lives in one place. `tests/desktop-consequences.sh` fails the build if an entry lacks one, and does it by extracting the *shipped* parser rather than reimplementing it.

    **One documented exception:** `install_deps()` in `install-suckless.sh` keeps inline arrays for its `pacman` and `apt-get` branches. A `.lst` holds one distro's package names, and those two are different names for the same libraries; only the `xbps` branch reads `build.lst`. They are vestigial fallbacks from when this repo still shipped `install-arch.sh` and `install.sh`, kept because `install-suckless.sh` is documented as standalone-runnable. Don't add a third distro this way — extend the format instead, or drop them.

    All four are one-package-per-line, `#`-commented, parsed with `sed`/`tr`/`grep` — no new dependency. Keep category comments (`# core system & display server`, etc.) as section dividers. **Never name the lists in a consumer** — `tests/pkglist.sh` and `ci.yml` both glob `packages/*.lst`, so a fifth tier is covered for free; a named loop silently stops covering whatever is added next.
