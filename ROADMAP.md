# 🖥️ Dots Desktop Roadmap — Fedora + dwm + X11

> Reference document based on a comparison between [HyDE-Project/HyDE](https://github.com/HyDE-Project/HyDE)
> (Arch + Hyprland + Wayland) and [yousseffjel/dots](https://github.com/yousseffjel/dots)
> (Fedora + dwm + X11). Goal: build a HyDE-like, full-desktop dotfiles framework
> with my own stack.

---

## 1. Project Comparison Overview

| Area | HyDE | My `dots` (current) |
|---|---|---|
| Distro | Arch Linux | Fedora |
| WM / Compositor | Hyprland (Wayland) | dwm (X11) |
| Display protocol | Wayland | X11 |
| Installer framework | Full modular installer (`install.sh` → pre/pkg/aur/pst stages) | Basic `scripts/` dir |
| Package management | Declarative lists (`pkg_core.lst`, `pkg_extra.lst`) | None |
| Config restore | Manifest-driven (`restore_cfg.psv`, fonts, services, shell) | Manual `config/` dir (only zsh, tmux) |
| Theming engine | Wallbash (wallpaper → colors → app themes), theme patcher | None |
| Docs | README, KEYBINDINGS.md, CONTRIBUTING, TESTING, CHANGELOG | 7-byte README |
| Tooling / CI | pre-commit, markdownlint, renovate, tests/, VM harness (hydevm) | None |
| Uninstall / versioning | `uninstall.sh`, `version.sh`, `migrations/` | None |

### HyDE repository structure (for reference)

```
HyDE/
├── Configs/.config/        # ~30 app configs (dunst, rofi, kitty, gtk-3.0, qt5ct, ...)
├── Scripts/
│   ├── install.sh          # orchestrator
│   ├── install_pre.sh      # sanity checks, backups
│   ├── install_pkg.sh      # package installation
│   ├── install_aur.sh      # AUR helper setup
│   ├── install_pst.sh      # post-install (services, shell)
│   ├── global_fn.sh        # shared logging/helper functions
│   ├── pkg_core.lst        # core package list
│   ├── pkg_extra.lst       # optional apps
│   ├── restore_cfg.psv     # pipe-separated config deploy manifest
│   ├── restore_cfg.sh      # config deployment w/ backups
│   ├── restore_fnt.sh      # fonts installer
│   ├── restore_svc.sh      # systemd services enabler
│   ├── restore_shl.sh      # shell setup (zsh + plugins)
│   ├── restore_thm.sh      # theme restore
│   ├── themepatcher.lst    # community themes
│   ├── uninstall.sh
│   ├── version.sh
│   ├── migrations/
│   └── hydevm/             # VM testing harness
├── Source/                 # wallbash theming engine, assets
├── tests/
├── KEYBINDINGS.md, TESTING.md, CHANGELOG.md, CONTRIBUTING.md, ...
```

### My current repo structure

```
dots/
├── .claude/
├── config/
│   ├── .zshrc
│   ├── tmux/
│   └── zsh/
├── scripts/
├── suckless/               # dwm, st, etc. (C sources)
├── .gitignore
└── README.md               # nearly empty
```

---

## 2. Framework / Infrastructure Points To Add

### 2.1 Modular installer pipeline
HyDE splits install into stages, orchestrated by `install.sh`, with a shared
`global_fn.sh` for logging, prompts, and error handling.

**To do:**
- `install.sh` — orchestrator: detect Fedora version, parse flags (`-i` install, `-r` restore only, `-t` theme only), call stages in order.
- `install_pre.sh` — sanity checks (not root, internet, Fedora detected), timestamped backup of existing configs.
- `install_pkg.sh` — install from package lists via `dnf`; enable **RPM Fusion** and needed **COPR** repos (Fedora's equivalent of AUR/chaotic-aur).
- `build_suckless.sh` — compile dwm/st/dmenu/slstatus/slock (`make clean install`), install X11 build deps first: `gcc make libX11-devel libXft-devel libXinerama-devel freetype-devel fontconfig-devel`.
- `restore_cfg.sh` — deploy dotfiles (see 2.3).
- `install_pst.sh` — enable services, set shell, generate `.xinitrc`, xdg-user-dirs.
- `global_fn.sh` — colored logging, `confirm()`, `pkg_installed()`, backup helpers.

### 2.2 Declarative package lists
Plain-text `.lst` files, one package per line, `#` comments, so users customize
without touching scripts.

**To do:**
- `pkgs/core.lst` — xorg, build deps, WM essentials (full list in §4).
- `pkgs/extra.lst` — optional apps (browser, editor, media).
- `pkgs/copr.lst` — packages needing COPR repos (format: `copr_repo|package`).
- Installer skips already-installed packages and logs missing ones.

### 2.3 Manifest-driven config restore with backups
HyDE's `restore_cfg.psv` maps repo path → target path with flags
(backup / overwrite / preserve). Never blindly overwrites.

**To do:**
- Either a `restore_cfg.psv`-style manifest + restore script, **or** use GNU `stow` (simpler: `stow -t ~ config`).
- Automatic timestamped backups: `~/.config/backup_YYYYMMDD_HHMMSS/`.
- `restore_fnt.sh` — Nerd Fonts + emoji fonts + `fc-cache -f`.
- `restore_svc.sh` — `systemctl enable` needed services.
- `restore_shl.sh` — zsh default shell, plugins (autosuggestions, syntax-highlighting), starship prompt.

### 2.4 Theming system (HyDE's biggest differentiator — X11 version)
HyDE's "wallbash" extracts wallpaper colors and generates themes for every app.

**To do:**
- Integrate **pywal** or **wallust** for color extraction from wallpaper.
- Apply colors via **`.Xresources`** → dwm & st read them with the **xresources patch**.
- Template files (pywal templates) for: dunst, picom, GTK css, starship. dmenu is
  out of scope here — its colors are compile-time constants in
  `suckless/dwm/config.def.h`, not a pywal-templatable runtime file.
- Wallpaper set with `feh --bg-fill` (persists via `~/.fehbg`).
- `theme-switch` script: pick theme → set wallpaper → regen colors → `xrdb -merge ~/.Xresources` → reload dwm (`kill -HUP` or restart patch) → `dunstctl reload` → re-run `~/.fehbg`.
- `themes/<name>/` dirs, each containing: `wallpapers/`, `xresources`, `gtk.theme` (theme name refs), `dunstrc.colors` — no `rofi.rasi` equivalent, see §8.

### 2.5 dwm patch & build management (unique to my stack)
- Document applied patches (recommended: **pertag, vanitygaps, systray, xresources, restartsig, statuscmd**).
- Keep patch `.diff` files in `suckless/dwm/patches/`.
- `rebuild.sh` — recompile all suckless tools after config/theme changes.

### 2.6 Uninstall + versioning + migrations
- `uninstall.sh` — remove deployed configs, restore latest backup.
- `VERSION` file + `version.sh`.
- `migrations/` folder for breaking-change upgrade scripts (later).

### 2.7 Documentation
- **README.md** — screenshots, feature list, one-line install (`git clone … && ./install.sh`), supported Fedora versions, dependencies.
- **KEYBINDINGS.md** — every dwm keybind from `config.h`, in a table.
- Optional: CONTRIBUTING.md, CHANGELOG.md, TESTING.md.

### 2.8 Testing & repo hygiene
- Test in clean Fedora VM or `toolbox`/`podman` container.
- `shellcheck` all scripts; pre-commit hook.
- GitHub Actions: lint shell scripts + test-build dwm/st in a Fedora container.

---

## 3. Full Desktop Component Map (HyDE → my X11 equivalent)

| Role | HyDE (Wayland) | My equivalent (X11) | Status |
|---|---|---|---|
| Window manager | Hyprland | dwm | ✅ have |
| Compositor | (built into Hyprland) | **picom** (transparency, shadows, vsync, no tearing) | ❌ add |
| Status bar | Waybar | **slstatus** or **dwmblocks** + status scripts | ❌ add |
| Launcher | Rofi | **dmenu** (vendored, patched, themed) | ✅ have |
| Notifications | Dunst / swaync | **dunst** (themed, with `dunstctl`) | ❌ add |
| Wallpaper | swww | **feh** (`~/.fehbg`) or nitrogen | ❌ add |
| Lock screen | hyprlock | **slock** (suckless) or i3lock | ❌ add |
| Idle / auto-lock | hypridle | **xss-lock** + `xset dpms`, or xautolock | ❌ add |
| Logout menu | wlogout | **dmenu powermenu script** (`config/dwm/bin/dwm-powermenu`: lock/logout/suspend/reboot/shutdown) | ✅ have |
| Screenshots | grim + slurp + satty | **maim + slop + xclip** (or flameshot) | ❌ add |
| Clipboard manager | cliphist + wl-clip-persist | **clipmenu** + **clipnotify** (Fedora: `skidnik/clipmenu` COPR, auto-enabled by `install-fedora.sh`), themed dmenu wrapper at `config/dwm/bin/dwm-clipmenu` | ✅ have on Fedora — Arch not wired yet |
| Color picker | hyprpicker | **xcolor** or gpick | ❌ add |
| Blue light filter | hyprsunset | **redshift** or gammastep | ❌ add |
| Display manager | SDDM | **startx + `.xinitrc`** (minimal, recommended) or ly/lightdm | ❌ add |
| Monitor management | nwg-displays | **xrandr** + arandr (GUI) + autorandr (profiles) | ❌ add |
| Session autostart | uwsm / exec-once | **`.xinitrc` + `autostart.sh`** | ❌ add |
| XDG portal | xdg-desktop-portal-hyprland | xdg-desktop-portal-gtk (file pickers, flatpak) | ❌ add |
| Auth agent | hyprpolkitagent | polkit-gnome / lxpolkit | ❌ add |
| System tray | Waybar tray | dwm **systray patch** or stalonetray | ❌ add |

---

## 4. Package Lists (Fedora names)

### 4.1 `pkgs/core.lst`

```
# ------------------------------- // Build deps (suckless)
gcc
make
git
libX11-devel
libXft-devel
libXinerama-devel
freetype-devel
fontconfig-devel

# ------------------------------- // Xorg
xorg-x11-server-Xorg
xorg-x11-xinit
xrandr
arandr
autorandr
xsettingsd
xset
xrdb                      # (part of xorg-x11-server-utils)
xclip
xdotool

# ------------------------------- // Desktop core
picom                     # compositor
dunst                     # notifications
# launcher/powermenu: dmenu (vendored), already have. clipboard: clipmenu +
# clipnotify, COPR-only (skidnik/clipmenu), enabled below — see §4.3
# see suckless/dmenu/ and packages/*.lst (installed by scripts/install-pkg.sh)
feh                       # wallpaper + image viewer
maim                      # screenshots
slop                      # region select
redshift                  # blue light filter
xss-lock                  # auto-lock hook
polkit-gnome              # auth agent
xdg-user-dirs
xdg-desktop-portal-gtk

# ------------------------------- // Audio (Fedora ships pipewire by default)
pipewire
pipewire-pulseaudio
wireplumber
pavucontrol
pamixer
playerctl

# ------------------------------- // Network / Bluetooth
NetworkManager
network-manager-applet
bluez
blueman

# ------------------------------- // Hardware
brightnessctl
udiskie

# ------------------------------- // Utilities
jq
ImageMagick
fzf
unzip
libnotify
fastfetch

# ------------------------------- // Theming
python3-pywal             # or wallust (COPR)
qt5ct
qt6ct
kvantum
gtk-murrine-engine
papirus-icon-theme

# ------------------------------- // Fonts
google-noto-emoji-color-fonts
jetbrains-mono-fonts      # + Nerd Font via script
```

### 4.2 `pkgs/extra.lst`

```
firefox                   # browser
alacritty                 # terminal (or use st from suckless/)
thunar                    # file manager (or pcmanfm)
thunar-archive-plugin
file-roller               # archive tool
vim                       # or neovim
tmux
zsh
starship                  # prompt (COPR or install script)
mpv                       # media player
```

### 4.3 Repos to enable in installer
- **RPM Fusion** (free + nonfree) — codecs, some apps.
- **COPR** as needed (e.g., `wallust`, `starship` if not packaged).
- **`skidnik/clipmenu`** — clipmenu + clipnotify, dwm-clipmenu's backend.
  ✅ done: `install-fedora.sh` auto-enables it (an explicit exception to the
  "COPR is opt-in" default, since the feature is a core keybind).

---

## 5. Configs To Add (`config/`)

| Config | Purpose | Notes |
|---|---|---|
| `x11/.xinitrc` | Session startup | `xrdb -merge`, autostart, `exec dwm` (loop for restart) |
| `x11/.Xresources` | Colors, fonts, DPI | Read by dwm/st via xresources patch; pywal writes here |
| `x11/.xprofile` | Env vars | `QT_QPA_PLATFORMTHEME=qt5ct`, locale, PATH |
| `x11/autostart.sh` | Autostart daemons | picom, dunst, `~/.fehbg`, slstatus, clipmenud (✅ wired, see `install-suckless.sh`), nm-applet, udiskie, xss-lock, polkit agent, redshift |
| `picom/picom.conf` | Compositor | vsync on, shadows, fade, opacity rules |
| `dunst/dunstrc` | Notifications | themed colors, urgency levels, keybind actions |
| `dwm/bin/` (dmenu scripts) | Launcher/menus/clipboard | dmenu theming lives in `suckless/dwm/config.def.h` (compile-time); `dwm-powermenu`/`dwm-clipmenu` scripts | ✅ have |
| `gtk-3.0/settings.ini` | GTK theming | theme, icons, cursor, fonts |
| `.gtkrc-2.0` | GTK2 apps | match GTK3 |
| `qt5ct` / `qt6ct` / Kvantum | Qt theming | match GTK |
| `alacritty/` or st `config.h` | Terminal | colors from Xresources/pywal |
| `zsh/` (expand) | Shell | plugins, aliases, starship init | ✅ partial |
| `tmux/` | Multiplexer | | ✅ have |
| `vim/` or `nvim/` | Editor | |
| `fastfetch/` | Fetch tool | custom logo/layout |
| `starship.toml` | Prompt | |

---

## 6. Scripts To Add (`scripts/`)

| Script | Purpose |
|---|---|
| `volume.sh` | pamixer up/down/mute + dunst OSD notification (progress bar via `-h int:value:`) |
| `brightness.sh` | brightnessctl + dunst OSD |
| `screenshot.sh` | maim full / region / window → save + xclip + notify |
| ~~`powermenu.sh`~~ | ✅ done as `config/dwm/bin/dwm-powermenu` (dmenu: lock, logout, suspend, reboot, shutdown) |
| `theme-switch.sh` | swap theme (wallpaper, colors, GTK, reload everything) |
| `wallpaper.sh` | random/select wallpaper + pywal regen |
| `statusbar/` | slstatus/dwmblocks modules: volume, battery, network, date, updates (`dnf check-update`) |
| `rebuild.sh` | recompile all suckless tools |
| `lock.sh` | slock wrapper (pause media, etc.) |
| ~~`clipboard.sh`~~ | ✅ done as `config/dwm/bin/dwm-clipmenu` (thin dmenu-themed wrapper around `clipmenu`) |

---

## 7. dwm Keybinds To Wire (`config.h` spawn commands)

| Key | Action |
|---|---|
| `Mod+Return` | terminal |
| ~~`Mod+d` rofi drun~~ | ✅ done — `Mod+p` runs `dmenu_run` (`suckless/dwm/config.def.h:92`) |
| ~~`Mod+x` powermenu~~ | ✅ done — `Super+Shift+x` runs `dwm-powermenu` (`suckless/dwm/config.def.h:132`) |
| ~~`Mod+v` clipboard menu~~ | ✅ done — `Super+v` runs `dwm-clipmenu` (`suckless/dwm/config.def.h:133`) |
| `Mod+l` (or dedicated) | lock screen |
| `Print` / `Shift+Print` / `Ctrl+Print` | full / region / window screenshot |
| `XF86AudioRaiseVolume/Lower/Mute` | volume.sh |
| `XF86MonBrightnessUp/Down` | brightness.sh |
| `XF86AudioPlay/Next/Prev` | playerctl |
| `Mod+w` | wallpaper/theme switcher |

Document all of these in `KEYBINDINGS.md`.

---

## 8. Theming Assets (`themes/`)

Each theme dir should contain:

```
themes/<name>/
├── wallpapers/
├── xresources            # color palette
├── theme.conf            # gtk_theme=, icon_theme=, cursor_theme=, font=
└── dunstrc.colors
```

dmenu has no per-theme rasi-equivalent: its colors are compile-time constants in
`suckless/dwm/config.def.h`, so a live theme switch would need to regenerate that
file and rebuild dmenu/dwm rather than just swap a runtime config — out of scope
until the theme-switcher script exists.

Plus:
- Nerd Fonts install script (`restore_fnt.sh`) — download from GitHub releases → `~/.local/share/fonts` → `fc-cache -f`.
- At least **one complete default theme** shipped in repo.
- Later: HyDE-style community "theme patcher" (git-clone external theme repos).

---

## 9. Priority / Build Order

1. **README + `install.sh` orchestrator** — usability first.
2. **Package lists + dnf installer + suckless build script.**
3. **Functioning desktop**: `.xinitrc`, autostart, picom, dunst, dmenu (✅ have), feh.
4. **Statusbar scripts + dwm keybinds** (volume/brightness/screenshot/powermenu).
5. **Config restore with backups** (manifest or stow).
6. **GTK/Qt theming + fonts.**
7. **Lock/idle/powermenu polish.**
8. **Theme switcher + pywal integration.**
9. **KEYBINDINGS.md, uninstaller, VERSION.**
10. **CI (shellcheck + Fedora container test-build), TESTING docs.**

---

## 10. Key Differences To Remember (Arch/Wayland → Fedora/X11)

- `pacman`/AUR → **`dnf` + RPM Fusion + COPR**.
- Wayland env flags (electron/code flags files) → **not needed on X11**.
- Hyprland config reload → **dwm requires recompile** (hence `rebuild.sh` + restartsig patch).
- Waybar modules → **shell scripts feeding slstatus/dwmblocks**.
- SDDM session files → **plain `startx`** keeps it suckless-minimal.
- Fedora already runs pipewire + NetworkManager by default — only add the control tools.
